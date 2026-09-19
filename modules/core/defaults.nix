{
  inputs,
  lib,
  den,
  ...
}:
let
  dotBootstrap = import ../../lib/bootstrap.nix { inherit inputs lib; };
  inherit (dotBootstrap) dotfilesLib;
  packagePolicy = import ../../lib/package-policy.nix { inherit inputs lib; };
in
{
  flake-file.inputs = {
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-pkgs = {
      url = "github:divyam234/nix-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cache = {
      url = "github:divyam234/nix-cache";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  imports = [ ./schema.nix ];

  den = {
    quirks = {
      caddyLayer4Routes.description = "Caddy layer4 route snippets emitted by service aspects.";
      caddyRoutes.description = "Caddy virtual host routes emitted by service aspects.";
      homeSecrets.description = "Secret contract paths required by Home Manager aspects.";
      nixosSecrets.description = "Secret contract paths required by NixOS aspects.";
      postgresDatabases.description = "PostgreSQL databases to create for service aspects.";
      postgresSchemas.description = "PostgreSQL schemas to create in the shared database for service aspects.";
    };

    schema = {
      home.includes = [
        (
          { home, ... }:
          {
            homeManager =
              { pkgs, ... }:
              {
                nix.package = pkgs.nix;
              };
          }
        )
      ];

      user = {
        includes = [
          den.aspects.users
        ];

        config.classes = lib.mkDefault [ "homeManager" ];
        options = {
          authorizedKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "SSH public keys added to authorized_keys for this user.";
          };
          email = lib.mkOption {
            type = lib.types.str;
            default = "bhunter@localhost";
            description = "Primary email address used by Git.";
          };
          fullName = lib.mkOption {
            type = lib.types.str;
            default = "Bhunter";
            description = "Account display name.";
          };
          gitName = lib.mkOption {
            type = lib.types.str;
            default = "Bhunter";
            description = "Author name used by Git.";
          };
          githubUser = lib.mkOption {
            type = lib.types.str;
            description = "GitHub account used for registry authentication.";
          };
          signingKey = lib.mkOption {
            type = lib.types.str;
            default = ".ssh/id_ed25519.pub";
            description = "SSH public key path used for Git commit signing (relative to home or absolute; ~ is not reliably expanded for SSH signing).";
          };
          signingPublicKey = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "SSH public key material used for Git commit signing.";
          };
          uid = lib.mkOption {
            type = lib.types.ints.positive;
            description = "Stable numeric UID used by system and runtime paths.";
          };
        };
      };
    };

    default = {
      includes = [
        den.batteries.define-user
        den.batteries.hostname
        den.batteries.inputs'
        den.batteries.self'
      ];
      homeManager =
        {
          config,
          homeSecrets,
          pkgs,
          ...
        }@args:
        let
          host = args.host or null;
          secrets = dotfilesLib.secrets.for { inherit config host; };
        in
        {
          imports = [ inputs.sops-nix.homeManagerModules.sops ];
          home.stateVersion = "26.05";
          home.packages = [ pkgs.sops ];
          _module.args.secrets = secrets;
          nixpkgs = packagePolicy;
          sops.age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
          sops.secrets = secrets.declare (secrets.select homeSecrets);
        };
      nixos =
        {
          config,
          host,
          nixosSecrets,
          ...
        }:
        let
          containers = {
            dataRoot = "/var/lib/oci-services";
            networkName = "svc";
            secretDir = "/run/secrets/container-env";
          };
          secrets = dotfilesLib.secrets.for { inherit config host; };
        in
        {
          imports = [
            inputs.sops-nix.nixosModules.sops
            inputs.disko.nixosModules.disko
            inputs.quadlet-nix.nixosModules.quadlet
          ];

          config = {
            _module.args = {
              inherit containers secrets;
              dotfiles = dotfilesLib;
            };
            sops = {
              defaultSopsFormat = "yaml";
              age.keyFile = "/var/lib/sops-nix/key.txt";
            };
            sops.secrets = secrets.declare (secrets.select nixosSecrets);
            nixpkgs = packagePolicy;
          };
        };
    };
  };
}

{
  inputs,
  lib,
  den,
  ...
}:
let
  dotBootstrap = import ../../lib/bootstrap.nix { inherit inputs lib; };
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
    nur.url = "github:nix-community/NUR";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-pkgs = {
      url = "github:divyam234/nix-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  imports = [
    ./schema.nix
    ./entities.nix
    ./dispatch.nix
  ];

  den = {
    quirks = {
      caddyLayer4Routes.description = "Caddy layer4 route snippets emitted by service aspects.";
      caddyRoutes.description = "Caddy virtual host routes emitted by service aspects.";
      containerDataDirs.description = "Persistent container data directories emitted by service aspects.";
    };

    schema = {
      home.includes = [
        den.batteries.mutual-provider
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
          den.batteries.mutual-provider
          (
            { host, user, ... }:
            lib.optionalAttrs ((host.homeManagerMode or "integrated") != "standalone") {
              nixos.home-manager = {
                sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
                useGlobalPkgs = false;
                useUserPackages = true;
                backupFileExtension = "hm-bak";
                extraSpecialArgs = { inherit inputs; };
                users.${user.userName} = {
                  _module.args.host = host;
                  nixpkgs = {
                    config.allowUnfree = true;
                    inherit (dotBootstrap) overlays;
                  };
                };
              };
            }
          )
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
            description = "Full name used by user and Git config.";
          };
          signingKey = lib.mkOption {
            type = lib.types.str;
            default = "~/.ssh/id_ed25519.pub";
            description = "SSH public key path used for Git commit signing.";
          };
          signingPublicKey = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "SSH public key material used for Git commit signing.";
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
          ...
        }@args:
        let
          host = args.host or null;
          secrets = dotBootstrap.extendedLib.denful.secrets.for { inherit config host; };
        in
        {
          home.stateVersion = "26.05";
          _module.args.secrets = secrets;
          sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
          sops.secrets = secrets.declare secrets.all;
        };
      nixos =
        {
          config,
          host ? null,
          user,
          ...
        }:
        let
          containers = {
            dataRoot = "/home/${user.userName}/.local/state/container-services";
            networkName = "svc";
            secretDir = "/run/secrets/container-env";
          };
          secrets = dotBootstrap.extendedLib.denful.secrets.for { inherit config host; };
        in
        {
          imports = [
            inputs.sops-nix.nixosModules.sops
            inputs.disko.nixosModules.disko
            inputs.quadlet-nix.nixosModules.quadlet
          ];

          config = {
            _module.args.lib = dotBootstrap.extendedLib;
            _module.args.secrets = secrets;
            _module.args.containers = containers;
            sops.secrets = secrets.declare secrets.all;
            nixpkgs = {
              config.allowUnfree = true;
              inherit (dotBootstrap) overlays;
            };
          };
        };
    };
  };
}

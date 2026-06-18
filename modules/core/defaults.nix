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

  den.quirks = {
    caddyLayer4Routes.description = "Caddy layer4 route snippets emitted by service aspects.";
    caddyRoutes.description = "Caddy virtual host routes emitted by service aspects.";
    containerDataDirs.description = "Persistent container data directories emitted by service aspects.";
    ociSecrets.description = "OCI secret environment files requested by service aspects.";
  };

  den.schema.home.includes = [
    den._.mutual-provider
    (
      { home, ... }:
      {
        homeManager =
          { pkgs, ... }:
          {
            _module.args.host = home.hostName or "unknown";
            nix.package = pkgs.nix;
          };
      }
    )
  ];

  den.schema.user = {
    includes = [
      den._.mutual-provider
      (
        { host, user, ... }:
        {
          nixos.home-manager = {
            sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
            useGlobalPkgs = false;
            useUserPackages = true;
            backupFileExtension = "hm-bak";
            extraSpecialArgs = { inherit inputs; };
            users.${user.userName} = {
              _module.args.host = host.hostName;
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
    };
  };

  den.default = {
    includes = [
      den._.define-user
      den._.hostname
    ];
    homeManager.home.stateVersion = "26.05";
  };

  den.default.nixos = {
    imports = [
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      inputs.disko.nixosModules.disko
      inputs.quadlet-nix.nixosModules.quadlet
    ];

    config = {
      _module.args.lib = dotBootstrap.extendedLib;
      nixpkgs = {
        config.allowUnfree = true;
        inherit (dotBootstrap) overlays;
      };
    };
  };
}

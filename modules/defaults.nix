{
  inputs,
  lib,
  den,
  ...
}:
let
  dotBootstrap = import ../lib/bootstrap.nix { inherit inputs lib; };
in
{
  # Nixicle-style context defaults: user entities opt into Home Manager inside
  # NixOS, and standalone homes get the same user/host mutual provider path.
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
            sharedModules = [
              inputs.sops-nix.homeManagerModules.sops
            ];
            useGlobalPkgs = false;
            useUserPackages = true;
            backupFileExtension = "hm-bak";
            extraSpecialArgs = {
              inherit inputs;
            };
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

  den.schema.host =
    { lib, ... }:
    {
      options = {
        secretsFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Host-specific SOPS file consumed by service aspects.";
        };

        domain = lib.mkOption {
          type = lib.types.str;
          default = "example.com";
          description = "Primary public domain used by service aspects.";
        };

        caddyEmail = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "ACME contact email. Defaults to admin@domain when unset.";
        };

        primaryDisplay = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Primary monitor metadata used by desktop aspects.";
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

  den.default.nixos =
    { ... }:
    {
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

{
  inputs,
  lib,
  den,
  ...
}:
let
  extendedLib = lib.extend (
    self: _super: {
      dot = import ../lib {
        inherit inputs;
        lib = self;
      };
    }
  );

  overlays = [
    inputs.nur.overlays.default
    inputs.rust-overlay.overlays.default
    (_final: prev: {
      zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
    })
    (final: _prev: {
      dot = extendedLib.dot;
      local = extendedLib.dot.importPackages final ../packages;
    })
  ];

in
{
  den = {
    schema.user.classes = lib.mkDefault [ "homeManager" ];

    schema.user.includes = [
      (
        { host, user, ... }:
        {
          nixos.home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-bak";
            extraSpecialArgs = {
              inherit inputs host user;
            };
            users.${user.userName}._module.args = {
              inherit host user inputs;
            };
          };
        }
      )
    ];

    schema.host =
      { host, lib, ... }:
      {
        options = {
          isLaptop = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          isServer = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          autologin = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          domain = lib.mkOption {
            type = lib.types.str;
            default = "example.com";
            description = "Primary public domain used by service aspects to derive hostnames.";
          };
          caddyEmail = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "ACME contact email. Defaults to the primary user's email when unset.";
          };
          primaryDisplay = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
          };
        };

        config.instantiate = lib.mkDefault (
          { modules }:
          inputs.nixpkgs.lib.nixosSystem {
            inherit modules;
            system = host.system;
            specialArgs = {
              inherit inputs;
              lib = extendedLib;
            };
          }
        );
      };

    schema.home =
      { home, lib, ... }:
      {
        config.instantiate = lib.mkDefault (
          { modules, ... }:
          let
            pkgs = import inputs.nixpkgs {
              system = home.system;
              inherit overlays;
              config.allowUnfree = true;
            };
          in
          inputs.home-manager.lib.homeManagerConfiguration {
            inherit pkgs modules;
            extraSpecialArgs = {
              inherit inputs;
              dotLib = extendedLib;
            };
          }
        );
      };

    default.includes = [
      den._.define-user
      den._.hostname
      den.aspects.boot
    ];

    default.homeManager.home.stateVersion = "25.11";
  };

  den.default.nixos =
    { pkgs, lib, ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
        inputs.disko.nixosModules.disko
      ];

      config = {
        _module.args = {
          lib = extendedLib;
        };

        nixpkgs = {
          config.allowUnfree = true;
          inherit overlays;
        };
      };
    };
}

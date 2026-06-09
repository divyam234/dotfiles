{
  inputs,
  lib,
  dotBootstrap,
  ...
}:
{
  den.schema.user.classes = lib.mkDefault [ "homeManager" ];

  den.schema.host =
    { host, lib, ... }:
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
          description = "Primary public domain used by service aspects to derive hostnames.";
        };

        caddyEmail = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "ACME contact email. Defaults to admin@domain when unset.";
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
            lib = dotBootstrap.extendedLib;
          };
        }
      );
    };

  den.schema.home =
    { home, lib, ... }:
    {
      config.instantiate = lib.mkDefault (
        { modules, ... }:
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = import inputs.nixpkgs {
            system = home.system;
            inherit (dotBootstrap) overlays;
            config.allowUnfree = true;
          };
          modules = modules ++ [ inputs.sops-nix.homeManagerModules.sops ];
          extraSpecialArgs = {
            inherit inputs;
            dotLib = dotBootstrap.extendedLib;
          };
        }
      );
    };
}

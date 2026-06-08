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
        role = lib.mkOption {
          type = lib.types.enum [
            "workstation"
            "server"
          ];
          description = "High-level host role used by host-dispatch.";
        };

        features = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Feature aspect names enabled for this host.";
        };

        services = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Service aspect names enabled for this host.";
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
        let
          pkgs = import inputs.nixpkgs {
            system = home.system;
            inherit (dotBootstrap) overlays;
            config.allowUnfree = true;
          };
        in
        inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs modules;
          extraSpecialArgs = {
            inherit inputs;
            dotLib = dotBootstrap.extendedLib;
          };
        }
      );
    };
}

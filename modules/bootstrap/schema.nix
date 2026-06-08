{
  inputs,
  lib,
  dotBootstrap,
  ...
}:
let
  serviceNames = [
    "adguard"
    "caddy"
    "camofox"
    "databasus"
    "forgejo"
    "gluetun"
    "hermes"
    "pgdog"
    "postgres"
    "redis"
    "restic"
    "siyuan"
    "vaultwarden"
  ];

  serviceOptions = lib.genAttrs serviceNames (name: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable the ${name} service aspect on this host.";
    };
  });
in
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
            "minimal"
          ];
          description = "High-level host role used by host-dispatch.";
        };

        features = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Feature aspect names enabled for this host.";
        };

        services = lib.mkOption {
          type = lib.types.submodule {
            options = serviceOptions;
          };
          default = { };
          description = "Typed service catalog enabled for this host.";
        };

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

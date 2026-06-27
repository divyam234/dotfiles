{ lib, den, ... }:
let
  registry = import ../../registry;
  serviceRegistryNames = builtins.attrNames registry.services;
in
{
  den.schema.host =
    { lib, ... }:
    {
      options = {
        services = lib.mkOption {
          type = lib.types.listOf (lib.types.enum serviceRegistryNames);
          default = [ ];
          description = "Directly requested hosted services.";
        };

        secretsFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Host-specific SOPS file consumed by aspects.";
        };

        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Primary public domain used by public services.";
        };

        caddyEmail = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "ACME contact email. Defaults to admin@domain when unset.";
        };

        tailscale = lib.mkOption {
          type = lib.types.submodule {
            options = {
              autoconnect = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Authenticate automatically using the configured SOPS OAuth client secret.";
              };
            };
          };
          default = { };
          description = "Host-specific Tailscale settings.";
        };

        greeter = lib.mkOption {
          type = lib.types.submodule {
            options.output.scale = lib.mkOption {
              type = lib.types.nullOr lib.types.float;
              default = 1.25;
              description = "Noctalia Greeter output scale override.";
            };
          };
          default = { };
          description = "Host-specific greeter settings.";
        };

        outputs = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Output connector name (e.g. eDP-1, HDMI-A-1).";
                };
                mode = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "1920x1080@74.973";
                  description = "Display mode string.";
                };
                scale = lib.mkOption {
                  type = lib.types.float;
                  default = 1.0;
                  description = "Output scale factor.";
                };
                position = lib.mkOption {
                  type = lib.types.nullOr (
                    lib.types.submodule {
                      options = {
                        x = lib.mkOption {
                          type = lib.types.int;
                          default = 0;
                        };
                        y = lib.mkOption {
                          type = lib.types.int;
                          default = 0;
                        };
                      };
                    }
                  );
                  default = null;
                  description = "Output position.";
                };
                off = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether this output is disabled.";
                };
              };
            }
          );
          default = [ { name = "eDP-1"; } ];
          description = "Monitor output configuration for niri.";
        };
      };
    };
}

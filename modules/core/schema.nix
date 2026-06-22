{ lib, den, ... }:
let
  registry = import ../../registry;
  roleNames = builtins.attrNames registry.roles;
  featureNames = builtins.attrNames registry.features;
  serviceRegistryNames = builtins.attrNames registry.services;
in
{
  den.schema.host =
    { lib, ... }:
    {
      options = {
        role = lib.mkOption {
          type = lib.types.enum roleNames;
          description = "Single broad host purpose.";
        };

        features = lib.mkOption {
          type = lib.types.listOf (lib.types.enum featureNames);
          default = [ ];
          description = "Directly requested host capabilities.";
        };

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
      };
    };
}

{ lib, den, ... }:
{
  den.schema.host =
    { lib, ... }:
    {
      options = {
        user = lib.mkOption {
          type = lib.types.str;
          description = "Primary user name associated with this host.";
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

        dns = lib.mkOption {
          type = lib.types.submodule {
            options.publicTarget =
              let
                addressTarget =
                  enabledByDefault:
                  lib.types.submodule {
                    options = {
                      enable = lib.mkOption {
                        type = lib.types.bool;
                        default = enabledByDefault;
                        description = "Whether to publish this address family.";
                      };
                      source = lib.mkOption {
                        type = lib.types.enum [
                          "static"
                          "local"
                          "external"
                        ];
                        default = "external";
                        description = "Whether the address is declared or discovered at runtime.";
                      };
                      address = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        default = null;
                        description = "Address used when source is static.";
                      };
                    };
                  };
              in
              {
                ipv4 = lib.mkOption {
                  type = addressTarget true;
                  default = { };
                  description = "Public IPv4 DNS target.";
                };
                ipv6 = lib.mkOption {
                  type = addressTarget false;
                  default = { };
                  description = "Public IPv6 DNS target.";
                };
              };

            options.refreshInterval = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "15m";
              description = "Periodic DNS reconciliation interval, or null for boot and configuration changes only.";
            };
          };
          default = { };
          description = "Host-specific DNS publication settings.";
        };

        rcloneWebdav = lib.mkOption {
          type = lib.types.submodule {
            options = {
              domain = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                example = "media.example.com";
                description = "Domain serving rclone WebDAV.";
              };
              remote = lib.mkOption {
                type = lib.types.str;
                default = "gpix:";
                description = "Rclone remote served over WebDAV.";
              };
              port = lib.mkOption {
                type = lib.types.port;
                default = 9000;
                description = "Host port used by the rclone WebDAV service.";
              };
              cacheDir = lib.mkOption {
                type = lib.types.str;
                default = "/var/cache/rclone-webdav";
                description = "Host directory used for the rclone VFS cache.";
              };
              cacheMode = lib.mkOption {
                type = lib.types.enum [
                  "off"
                  "minimal"
                  "writes"
                  "full"
                ];
                default = "full";
                description = "Rclone VFS cache mode.";
              };
              cacheMaxAge = lib.mkOption {
                type = lib.types.str;
                default = "720h";
                description = "Maximum age of objects in the VFS cache.";
              };
              cacheMaxSize = lib.mkOption {
                type = lib.types.str;
                default = "100GiB";
                description = "Maximum total size of the VFS cache.";
              };
              readChunkSize = lib.mkOption {
                type = lib.types.str;
                default = "128Mi";
                description = "Initial VFS read chunk size.";
              };
              readChunkSizeLimit = lib.mkOption {
                type = lib.types.str;
                default = "128Mi";
                description = "Maximum VFS read chunk size.";
              };
              readAhead = lib.mkOption {
                type = lib.types.str;
                default = "384Mi";
                description = "Additional VFS data read ahead of the current position.";
              };
              bufferSize = lib.mkOption {
                type = lib.types.str;
                default = "32Mi";
                description = "In-memory buffer size used per open file.";
              };
            };
          };
          default = { };
          description = "Host-specific rclone WebDAV settings.";
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

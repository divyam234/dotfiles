{ lib, den, ... }:
{
  den.schema.host =
    { config, lib, ... }:
    let
      positiveFloat = lib.types.addCheck lib.types.float (value: value > 0.0);
      staticTargetValid = target: target.source != "static" || target.address != null;
    in
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

        caddy = lib.mkOption {
          type = lib.types.submodule {
            options.cacheDir = lib.mkOption {
              type = lib.types.str;
              default = "/var/cache/caddy";
              description = "Host directory mounted as the Caddy cache.";
            };
          };
          default = { };
          description = "Host-specific Caddy settings.";
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

        teldrive = lib.mkOption {
          type = lib.types.submodule {
            options = {
              databaseHost = lib.mkOption {
                type = lib.types.str;
                default = "pgdog";
                description = "PostgreSQL connection host used by TelDrive.";
              };
              port = lib.mkOption {
                type = lib.types.nullOr lib.types.port;
                default = null;
                description = "Optional host port published to TelDrive's container port 8080.";
              };
              exposeThroughCaddy = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether to publish TelDrive through this host's Caddy instance.";
              };
              runWorkers = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether this TelDrive instance runs background workers.";
              };
              useMtproxy = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether TelDrive connects to Telegram through MTProxy.";
              };
              download = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    bots = lib.mkOption {
                      type = lib.types.nullOr lib.types.int;
                      default = null;
                    };
                    clientPool = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                    };
                    readBuffers = lib.mkOption {
                      type = lib.types.nullOr lib.types.int;
                      default = null;
                    };
                    readParallel = lib.mkOption {
                      type = lib.types.nullOr lib.types.int;
                      default = null;
                    };
                  };
                };
                default = { };
                description = "Optional Telegram download settings; null values are omitted.";
              };
            };
          };
          default = { };
          description = "Host-specific TelDrive settings.";
        };

        rcloneWebdav = lib.mkOption {
          type = lib.types.submodule {
            options = {
              remote = lib.mkOption {
                type = lib.types.str;
                default = "gpix:";
                description = "Rclone remote served over WebDAV.";
              };
              port = lib.mkOption {
                type = lib.types.port;
                default = 9000;
                description = "Tailnet port used by the WebDAV server.";
              };
              configDatabaseHost = lib.mkOption {
                type = lib.types.str;
                default = "netcup";
                description = "PostgreSQL host containing the shared rclone configuration.";
              };
              configDatabasePort = lib.mkOption {
                type = lib.types.port;
                default = 6432;
                description = "PostgreSQL port containing the shared rclone configuration.";
              };
              extraArgs = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                example = [
                  "--read-only"
                  "--baseurl=/media"
                ];
                description = "Additional arguments passed to rclone serve webdav.";
              };
              cors = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Allow cross-origin WebDAV requests from any origin.";
              };
              cacheDir = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Host directory used for the rclone VFS cache.";
              };
              vfs = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    dirCacheTime = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    pollInterval = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    blockNormDupes = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                    };
                    cacheMaxAge = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    cacheMaxSize = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    cacheMinFreeSpace = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    cacheMode = lib.mkOption {
                      type = lib.types.nullOr (
                        lib.types.enum [
                          "off"
                          "minimal"
                          "writes"
                          "full"
                        ]
                      );
                      default = null;
                    };
                    cachePollInterval = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    caseInsensitive = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                    };
                    diskSpaceTotalSize = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    fastFingerprint = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                    };
                    handleCaching = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    links = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                    };
                    metadataExtension = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    readAhead = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    readChunkSize = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    readChunkSizeLimit = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    readChunkStreams = lib.mkOption {
                      type = lib.types.nullOr lib.types.int;
                      default = null;
                    };
                    readWait = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    refresh = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                    };
                    usedIsSize = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                    };
                    writeBack = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                    writeWait = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                    };
                  };
                };
                default = { };
                description = "Optional rclone VFS settings; null values are omitted.";
              };
            };
          };
          default = { };
          description = "Host-specific rclone WebDAV settings.";
        };

        greeter = lib.mkOption {
          type = lib.types.submodule {
            options.output.scale = lib.mkOption {
              type = lib.types.nullOr positiveFloat;
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
                  type = positiveFloat;
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

      config.assertions = [
        {
          assertion = staticTargetValid config.dns.publicTarget.ipv4;
          message = "Static public IPv4 DNS requires an address.";
        }
        {
          assertion = staticTargetValid config.dns.publicTarget.ipv6;
          message = "Static public IPv6 DNS requires an address.";
        }
        {
          assertion = lib.all (output: !(output.off && output.mode != null)) config.outputs;
          message = "Disabled outputs must not declare a display mode.";
        }
      ];
    };
}

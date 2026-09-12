{ den, ... }:
{
  den.schema.host =
    { lib, ... }:
    let
      nullable =
        type:
        lib.mkOption {
          type = lib.types.nullOr type;
          default = null;
        };
    in
    {
      options.rcloneWebdav = lib.mkOption {
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
                  dirCacheTime = nullable lib.types.str;
                  pollInterval = nullable lib.types.str;
                  blockNormDupes = nullable lib.types.bool;
                  cacheMaxAge = nullable lib.types.str;
                  cacheMaxSize = nullable lib.types.str;
                  cacheMinFreeSpace = nullable lib.types.str;
                  cacheMode = nullable (
                    lib.types.enum [
                      "off"
                      "minimal"
                      "writes"
                      "full"
                    ]
                  );
                  cachePollInterval = nullable lib.types.str;
                  caseInsensitive = nullable lib.types.bool;
                  diskSpaceTotalSize = nullable lib.types.str;
                  fastFingerprint = nullable lib.types.bool;
                  handleCaching = nullable lib.types.str;
                  links = nullable lib.types.bool;
                  metadataExtension = nullable lib.types.str;
                  readAhead = nullable lib.types.str;
                  readChunkSize = nullable lib.types.str;
                  readChunkSizeLimit = nullable lib.types.str;
                  readChunkStreams = nullable lib.types.int;
                  readWait = nullable lib.types.str;
                  refresh = nullable lib.types.bool;
                  usedIsSize = nullable lib.types.bool;
                  writeBack = nullable lib.types.str;
                  writeWait = nullable lib.types.str;
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
    };

  den.aspects.rclone-webdav = { host, user, ... }: {
    nixosSecrets = [
      "postgres/user"
      "postgres/password"
    ];

    nixos =
      {
        containers,
        lib,
        pkgs,
        secrets,
        ...
      }:
      let
        cfg = host.rcloneWebdav;
        environmentFile = "${containers.secretDir}/rclone-webdav.env";
        optionalEnv =
          name: value:
          lib.optional (value != null)
            "${name}=${if builtins.isBool value then lib.boolToString value else toString value}";
        vfsEnvironment = lib.concatLists [
          (optionalEnv "RCLONE_DIR_CACHE_TIME" cfg.vfs.dirCacheTime)
          (optionalEnv "RCLONE_POLL_INTERVAL" cfg.vfs.pollInterval)
          (optionalEnv "RCLONE_VFS_BLOCK_NORM_DUPES" cfg.vfs.blockNormDupes)
          (optionalEnv "RCLONE_VFS_CACHE_MAX_AGE" cfg.vfs.cacheMaxAge)
          (optionalEnv "RCLONE_VFS_CACHE_MAX_SIZE" cfg.vfs.cacheMaxSize)
          (optionalEnv "RCLONE_VFS_CACHE_MIN_FREE_SPACE" cfg.vfs.cacheMinFreeSpace)
          (optionalEnv "RCLONE_VFS_CACHE_MODE" cfg.vfs.cacheMode)
          (optionalEnv "RCLONE_VFS_CACHE_POLL_INTERVAL" cfg.vfs.cachePollInterval)
          (optionalEnv "RCLONE_VFS_CASE_INSENSITIVE" cfg.vfs.caseInsensitive)
          (optionalEnv "RCLONE_VFS_DISK_SPACE_TOTAL_SIZE" cfg.vfs.diskSpaceTotalSize)
          (optionalEnv "RCLONE_VFS_FAST_FINGERPRINT" cfg.vfs.fastFingerprint)
          (optionalEnv "RCLONE_VFS_HANDLE_CACHING" cfg.vfs.handleCaching)
          (optionalEnv "RCLONE_VFS_LINKS" cfg.vfs.links)
          (optionalEnv "RCLONE_VFS_METADATA_EXTENSION" cfg.vfs.metadataExtension)
          (optionalEnv "RCLONE_VFS_READ_AHEAD" cfg.vfs.readAhead)
          (optionalEnv "RCLONE_VFS_READ_CHUNK_SIZE" cfg.vfs.readChunkSize)
          (optionalEnv "RCLONE_VFS_READ_CHUNK_SIZE_LIMIT" cfg.vfs.readChunkSizeLimit)
          (optionalEnv "RCLONE_VFS_READ_CHUNK_STREAMS" cfg.vfs.readChunkStreams)
          (optionalEnv "RCLONE_VFS_READ_WAIT" cfg.vfs.readWait)
          (optionalEnv "RCLONE_VFS_REFRESH" cfg.vfs.refresh)
          (optionalEnv "RCLONE_VFS_USED_IS_SIZE" cfg.vfs.usedIsSize)
          (optionalEnv "RCLONE_VFS_WRITE_BACK" cfg.vfs.writeBack)
          (optionalEnv "RCLONE_VFS_WRITE_WAIT" cfg.vfs.writeWait)
        ];
      in
      {
        sops.templates."rclone-webdav.env" = secrets.mkTemplate {
          name = "rclone-webdav.env";
          content = ''
            RCLONE_CONFIG=postgres://${secrets.postgres.user}:${secrets.postgres.password}@${cfg.configDatabaseHost}:${toString cfg.configDatabasePort}/postgres?schema=rclone
          '';
        };

        assertions = [
          {
            assertion = cfg.vfs.cacheMode == null || cfg.vfs.cacheMode == "off" || cfg.cacheDir != null;
            message = "rcloneWebdav.cacheDir must be set when VFS caching is enabled.";
          }
        ];

        systemd.services.rclone-webdav = {
          description = "Rclone WebDAV server";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = lib.optional (cfg.cacheDir != null) cfg.cacheDir;
          serviceConfig = {
            Type = "simple";
            User = user.userName;
            Group = "users";
            Environment = [
              "RCLONE_ADDR=0.0.0.0:${toString cfg.port}"
            ]
            ++ lib.optional cfg.cors "RCLONE_ALLOW_ORIGIN=*"
            ++ optionalEnv "RCLONE_CACHE_DIR" cfg.cacheDir
            ++ vfsEnvironment;
            EnvironmentFile = environmentFile;
            ExecStart = lib.escapeShellArgs (
              [
                "${pkgs.rclone}/bin/rclone"
                "serve"
                "webdav"
                cfg.remote
              ]
              ++ cfg.extraArgs
            );
            Restart = "on-failure";
            RestartSec = "10s";
            NoNewPrivileges = true;
            MemoryMax = "2G";
            CPUQuota = "200%";
          }
          // lib.optionalAttrs (cfg.cacheDir != null) {
            ExecStartPre = "+${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${lib.escapeShellArg cfg.cacheDir}";
          };
        };
      };
  };
}

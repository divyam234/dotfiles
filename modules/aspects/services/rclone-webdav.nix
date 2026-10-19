{ den, inputs, ... }:
{
  den.schema.host =
    { lib, ... }:
    {
      options.rcloneWebdav = lib.mkOption {
        type = lib.types.submodule {
          options = {
            remote = lib.mkOption {
              type = lib.types.str;
              default = "drive:";
              description = "Rclone remote served over WebDAV.";
            };
            port = lib.mkOption {
              type = lib.types.port;
              default = 9000;
              description = "Port the WebDAV server listens on.";
            };
            cacheDir = lib.mkOption {
              type = lib.types.str;
              default = "/mnt/drive/rclone";
              description = "Directory rclone uses for VFS caching.";
            };
          };
        };
        default = { };
        description = "Host-specific rclone WebDAV settings.";
      };
    };

  den.aspects.rclone-webdav = { host, ... }: {
    homeSecrets = [
      "postgres/user"
      "postgres/password"
    ];

    homeManager =
      {
        config,
        secrets,
        ...
      }:
      let
        cfg = host.rcloneWebdav;
        rcloneEnv = "${config.xdg.configHome}/rclone/rclone-webdav.env";
        endpoint = "netcup:6432/postgres?schema=rclone&init_schema=false";
      in
      {
        imports = [ inputs.nix-pkgs.homeManagerModules.rclone ];

        sops.templates."rclone-webdav.env" = secrets.mkTemplate {
          name = "rclone-webdav.env";
          path = rcloneEnv;
          mode = "0400";
          content = ''
            RCLONE_CONFIG=postgres://${secrets.postgres.user}:${secrets.postgres.password}@${endpoint}
          '';
        };

        programs.rclone.enable = true;

        services.rclone.serve.webdav = {
          enable = true;
          protocol = "webdav";
          remote = cfg.remote;
          environmentFile = rcloneEnv;
          settings = {
            addr = [ "0.0.0.0:${toString cfg.port}" ];
            cache-dir = cfg.cacheDir;
            vfs-cache-mode = "full";
            vfs-cache-max-age = "8670h";
            dir-cache-time = "24h";
            allow-origin = "*";
            poll-interval = "1s";
            vfs-read-ahead = "384Mi";
          };
        };
      };
  };
}

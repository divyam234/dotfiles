{ den, ... }:
{
  den.aspects.stash = { host, user, ... }: {
    nixosSecrets = [
      "postgres/user"
      "postgres/password"
      "stash/secret_key"
    ];

    postgresSchemas.stash = { };

    caddyRoutes.stash = {
      host = "stash.${host.domain}";
      access = "tailnet";
      upstreams = [ "stash:8080" ];
    };

    nixos =
      {
        config,
        lib,
        pkgs,
        secrets,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
        downloadsDir = "${config.users.users.${user.userName}.home}/downloads";
        cacheDir = "/var/cache/stash";
        mkStash = command: {
          secretEnvironment = {
            STASH_DATABASE_URL = "postgres://${secrets.postgres.user}:${secrets.postgres.password}@pgdog:6432/postgres?sslmode=disable";
            STASH_SECRET_KEY = secrets.stash.secret_key;
            RCLONE_CONFIG = "postgres://${secrets.postgres.user}:${secrets.postgres.password}@pgdog:6432/postgres?schema=rclone&init_schema=false";
          };
          containerConfig = {
            image = "ghcr.io/elevatedai/stash:latest";
            exec = [ command ];
            networkAliases = [ (if command == "serve" then "stash" else "stash-worker") ];
            environments = {
              STASH_CAMOFLARE_URL = "http://host.containers.internal:8191";
            }
            // lib.optionalAttrs (command == "serve") {
              RCLONE_VFS_CACHE_MODE = "full";
              RCLONE_VFS_CACHE_MAX_AGE = "8670h";
              RCLONE_VFS_CACHE_MAX_SIZE = "50G";
              RCLONE_POLL_INTERVAL = "1s";
            };
            volumes =
              if command == "serve" then
                [
                  "${cacheDir}/images:/home/nonroot/.cache/stash/images"
                  "${cacheDir}/rclone/${command}:/home/nonroot/.cache/rclone"
                ]
              else
                [
                  "${downloadsDir}:/downloads"
                ];
          };
          unitConfig = {
            After = [
              quadlet.containers.pgdog.ref
              "postgres-provision.service"
              "camoflare.service"
            ];
            Requires = [
              quadlet.containers.pgdog.ref
              "postgres-provision.service"
              "camoflare.service"
            ];
          };
          serviceConfig = {
            ExecStartPre =
              "${pkgs.coreutils}/bin/install -d -m 0750 -o 1000 -g 100 "
              + (if command == "serve" then "${cacheDir}/images ${cacheDir}/rclone/${command}" else downloadsDir);
            MemoryMax = "2G";
            CPUQuota = "200%";
          };
        };
      in
      {
        virtualisation.quadlet.containers = {
          stash = mkStash "serve";
          stash-worker = mkStash "worker";
        };
      };
  };
}

{ den, ... }:
let
  stashEnv = secrets: ''
    STASH_DATABASE_URL=postgres://${secrets.postgres.user}:${secrets.postgres.password}@pgdog:6432/postgres
    STASH_SECRET_KEY=${secrets.stash.secret_key}
    RCLONE_CONFIG_TDRIVE_API_KEY=${secrets.teldrive.api_key}
  '';

  baseRcloneEnv = {
    RCLONE_CONFIG_TDRIVE_TYPE = "teldrive";
    RCLONE_CONFIG_TDRIVE_HASH_ENABLED = "false";
    RCLONE_CONFIG_TDRIVE_API_HOST = "http://teldrive:8080";
  };
in
{
  den.aspects.stash = { user, host, ... }: {
    nixosSecrets = [
      "postgres/user"
      "postgres/password"
      "stash/secret_key"
      "teldrive/api_key"
    ];

    caddyRoutes.stash = {
      host = "stash.${host.domain}";
      access = "tailnet";
      upstreams = [ "stash:8080" ];
    };

    nixos =
      {
        containers,
        pkgs,
        secrets,
        ...
      }:
      {
        sops.templates."stash.env" = secrets.mkTemplate {
          name = "stash.env";
          content = stashEnv secrets;
        };

        virtualisation.quadlet.containers.stash = {
          containerConfig = {
            image = "ghcr.io/elevatedai/stash";
            exec = "serve";
            networkAliases = [ "stash" ];
            environmentFiles = [ "${containers.secretDir}/stash.env" ];
            environments = baseRcloneEnv // {
              RCLONE_CACHE_DIR = "/var/cache/rclone";
              RCLONE_VFS_CACHE_MODE = "full";
              RCLONE_VFS_CACHE_MAX_AGE = "8670h";
              RCLONE_VFS_CACHE_MAX_SIZE = "300GiB";
              RCLONE_DIR_CACHE_TIME = "8670h";
              RCLONE_POLL_INTERVAL = "1s";
              STASH_IMAGE_CACHE_DIR = "/var/cache/images";
              STASH_IMAGE_CACHE_MAX_SIZE = "30G";
              GOMAXPROCS = "4";
            };
            volumes = [
              "/var/cache/rclone:/var/cache/rclone"
              "/var/cache/images:/var/cache/images"
            ];
          };
          unitConfig = {
            After = [
              "ghcr-auth.service"
              "tailscale-autoconnect.service"
            ];
            Requires = [ "ghcr-auth.service" ];
            Wants = [ "tailscale-autoconnect.service" ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -dm750 -o ${user.userName} -g users /var/cache/rclone /var/cache/images";
            MemoryMax = "2G";
            CPUQuota = "400%";
          };
        };
      };
  };

  den.aspects.stash-worker = { user, ... }: {
    nixosSecrets = [
      "postgres/user"
      "postgres/password"
      "stash/secret_key"
      "teldrive/api_key"
    ];

    nixos =
      {
        config,
        containers,
        pkgs,
        secrets,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        sops.templates."stash-worker.env" = secrets.mkTemplate {
          name = "stash-worker.env";
          content = stashEnv secrets;
        };

        virtualisation.quadlet.containers.stash-worker = {
          containerConfig = {
            image = "ghcr.io/elevatedai/stash";
            exec = "worker";
            environmentFiles = [ "${containers.secretDir}/stash-worker.env" ];
            environments = baseRcloneEnv;
            volumes = [ "/home/${user.userName}/downloads:/downloads" ];
            stopTimeout = 60;
          };
          unitConfig = {
            After = [
              "ghcr-auth.service"
              quadlet.containers.postgres.ref
              "postgres-provision.service"
            ];
            Requires = [
              "ghcr-auth.service"
              quadlet.containers.postgres.ref
              "postgres-provision.service"
            ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -dm750 -o ${user.userName} -g users /home/${user.userName}/downloads";
            TimeoutStopSec = "70s";
          };
        };
      };
  };
}

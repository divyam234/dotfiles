{ den, ... }:
{
  den.aspects.stash = { user,host, ... }: {
    caddyRoutes.stash = {
      host = "stash.${host.domain}";
      access = "tailnet";
      upstreams = [ "stash:8080" ];
      extraConfig = ''
        @asset path /api/assets/*
        route @asset {
          header Cache-Control "public, max-age=31536000, immutable"
          vips {
            cache_dir /var/cache/caddy/vips
            cache_max_size 20GiB
            quality 82
            max_dimension 8192
            max_pixels 40000000
            max_source_size 64MiB
          }
        }
      '';
    };

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
        sops.templates."stash.env" = {
          path = "${containers.secretDir}/stash.env";
          mode = "0440";
          content = ''
            STASH_DATABASE_URL=postgres://${secrets.postgres.user}:${secrets.postgres.password}@pgdog:6432/postgres
            STASH_SECRET_KEY=${secrets.stash.secret_key}
            RCLONE_CONFIG_TDRIVE_API_KEY=${secrets.teldrive.api_key}
          '';
        };

        virtualisation.quadlet.containers.stash = {
          autoStart = true;
          containerConfig = {
            name = "stash";
            image = "ghcr.io/elevatedai/stash";
            exec = "serve";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "stash" ];
            environmentFiles = [ "${containers.secretDir}/stash.env" ];
            environments = {
              RCLONE_CONFIG_TDRIVE_TYPE="teldrive";
              RCLONE_CONFIG_TDRIVE_HASH_ENABLED="false";
              RCLONE_CONFIG_TDRIVE_API_HOST="http://teldrive:8080";
              RCLONE_CACHE_DIR = "/var/cache/rclone";
              RCLONE_VFS_CACHE_MODE = "full";
              RCLONE_VFS_CACHE_MAX_AGE = "8670h";
              RCLONE_DIR_CACHE_TIME = "8670h";
            };
            volumes = [ "/var/cache/rclone:/var/cache/rclone" ];
            autoUpdate = "registry";
          };
          unitConfig = {
            After = [
              "ghcr-auth.service"
              "tailscale-autoconnect.service"
            ];
            Requires = [ "ghcr-auth.service" ];
            Wants = [ "tailscale-autoconnect.service" ];
            RequiresMountsFor = [ "/mnt/external/rclone" ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users /var/cache/rclone";
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            MemoryMax = "2G";
            CPUQuota = "200%";
          };
        };
      };
  };

  den.aspects.stash-worker = { user, ... }: {
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
        sops.templates."stash-worker.env" = {
          path = "${containers.secretDir}/stash-worker.env";
          mode = "0440";
          content = ''
            STASH_DATABASE_URL=postgres://${secrets.postgres.user}:${secrets.postgres.password}@pgdog:6432/postgres
            STASH_SECRET_KEY=${secrets.stash.secret_key}
            RCLONE_CONFIG_TDRIVE_API_KEY=${secrets.teldrive.api_key}
          '';
        };

        virtualisation.quadlet.containers.stash-worker = {
          autoStart = true;
          containerConfig = {
            name = "stash-worker";
            image = "ghcr.io/elevatedai/stash";
            exec = "worker";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            environmentFiles = [ "${containers.secretDir}/stash-worker.env" ];
            environments = {
              RCLONE_CONFIG_TDRIVE_TYPE="teldrive";
              RCLONE_CONFIG_TDRIVE_HASH_ENABLED="false";
              RCLONE_CONFIG_TDRIVE_API_HOST="http://teldrive:8080";
            };
            volumes = [ "/home/${user.userName}/downloads:/downloads" ];
            autoUpdate = "registry";
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
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users /home/${user.userName}/downloads";
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            TimeoutStopSec = "70s";
          };
        };
      };
  };
}

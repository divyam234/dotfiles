{ den, ... }:
{
  den.aspects.stash = { host, ... }: {
    caddyRoutes.stash = {
      host = "stash.${host.domain}";
      access = "tailnet";
      upstreams = [ "stash:8080" ];
      extraConfig = ''
        @cacheable `path('/api/assets/*') || path_regexp('^/api/scenes/[^/]+/stream$')`
        route @cacheable {
          @asset path /api/assets/*
          route @asset {
            vips {
              cache_dir /var/cache/caddy/vips
              cache_max_size 20GiB
              quality 82
              max_dimension 8192
              max_pixels 40000000
              max_source_size 64MiB
            }
          }

          varc http://stash:8080 {
            cache_dir /var/cache/caddy/varc
            key {path}
            append_uri on
            ignore_query on
            forward_header *

            chunk_size 128MiB
            chunk_size_limit 128MiB
            max_inflight_bytes 512MiB
            read_ahead 0
            max_size 400GiB
            max_age 8670h
            poll_interval 1m
            shard_level 1

            timeout 60s
            probe_timeout 15s
            dial_timeout 10s
            response_header_timeout 30s
            max_idle_conns 128
            stale_if_error 1h

            debug_headers on
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
            DATABASE_URL=postgres://${secrets.postgres.user}:${secrets.postgres.password}@netcup:6432/postgres
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
            environments.RCLONE_USE_MMAP = "true";
            autoUpdate = "registry";
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
            DATABASE_URL=postgres://${secrets.postgres.user}:${secrets.postgres.password}@pgdog:6432/postgres
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
              RCLONE_USE_MMAP = "true";
              HTTP_PROXY = "http://gluetun:3128";
              HTTPS_PROXY = "http://gluetun:3128";
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

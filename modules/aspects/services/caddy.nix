{ den, ... }:
{
  den.aspects.caddy = { user, ... }: {
    includes = [ den.aspects.oci-service ];
    ociSecrets = [ "caddy" ];
    containerDataDirs = {
      caddy = {
        user = user.userName;
        group = "users";
      };
      "caddy-config" = {
        user = user.userName;
        group = "users";
      };
    };

    nixos =
      {
        config,
        caddyLayer4Routes,
        caddyRoutes,
        containers,
        lib,
        host,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
        global = {
          email = acmeEmail;
          admin = "off";
          debug = false;
          extraGlobalConfig = [ ];
          layer4Routes = lib.flatten caddyLayer4Routes;
        };
        routes = lib.foldl' lib.recursiveUpdate { } caddyRoutes;
        caddyRouteType = lib.types.submodule (_: {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to render this Caddy route.";
            };

            host = lib.mkOption {
              type = lib.types.str;
              description = "Public hostname for the route.";
            };

            upstreams = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "One or more Caddy reverse_proxy upstreams.";
            };

            encode = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to enable zstd/gzip encoding.";
            };

            cacheStatic = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether to add long-lived caching headers for static assets.";
            };

            securityHeaders = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to add a small secure-header baseline.";
            };

            tls = lib.mkOption {
              type = lib.types.enum [
                "cloudflare"
                "internal"
                "auto"
                "off"
              ];
              default = "cloudflare";
              description = "TLS mode. cloudflare uses the Caddy Cloudflare DNS plugin and CLOUDFLARE_API_TOKEN.";
            };

            extraConfig = lib.mkOption {
              type = lib.types.lines;
              default = "";
              description = "Extra raw Caddyfile directives inserted before reverse_proxy.";
            };
          };
        });

        acmeEmail = if host.caddyEmail != null then host.caddyEmail else "admin@${host.domain}";
      in
      {
        config = {
          environment.etc."caddy/Caddyfile".text = lib.denful.mkCaddyfile {
            inherit global routes;
          };

          systemd.services.caddy.restartTriggers = [
            config.environment.etc."caddy/Caddyfile".source
          ];

          virtualisation.quadlet.containers.caddy = {
            autoStart = true;
            containerConfig = {
              name = "caddy";
              image = "ghcr.io/tgdrive/caddy";
              networks = [ quadlet.networks.${containers.networkName}.ref ];
              networkAliases = [ "caddy" ];
              environmentFiles = [ "${containers.secretDir}/caddy.env" ];
              publishPorts = [
                "80:80"
                "443:443"
                "443:443/udp"
              ];
              volumes = [
                "/etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro"
                "${containers.dataRoot}/caddy:/data"
                "${containers.dataRoot}/caddy-config:/config"
              ];
              healthCmd = "caddy version >/dev/null || exit 1";
              autoUpdate = "registry";
            };
            serviceConfig = {
              Restart = "always";
              RestartSec = "10s";
              NoNewPrivileges = true;
              MemoryMax = "512M";
              CPUQuota = "100%";
            };
          };
        };
      };
  };
}

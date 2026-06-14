{ den, ... }:
{
  den.aspects.caddy = {
    includes = [ den.aspects.oci-service ];

    nixos =
      {
        config,
        lib,
        host,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
        containers = config.dot.containers;
        caddyRouteType = lib.types.submodule (
          { ... }:
          {
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
          }
        );

        acmeEmail = if host.caddyEmail != null then host.caddyEmail else "admin@${host.domain}";
      in
      {
        options.dot.caddy = {
          global = {
            email = lib.mkOption {
              type = lib.types.str;
              default = "admin@example.com";
              description = "ACME contact email used in the generated Caddyfile.";
            };

            admin = lib.mkOption {
              type = lib.types.str;
              default = "off";
              description = "Caddy admin endpoint value.";
            };

            debug = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable Caddy debug logging.";
            };

            extraGlobalConfig = lib.mkOption {
              type = lib.types.listOf lib.types.lines;
              default = [ ];
              description = "Extra global Caddyfile directives.";
            };
          };

          routes = lib.mkOption {
            type = lib.types.attrsOf caddyRouteType;
            default = { };
            description = "Routes collected from service aspects and rendered by the Caddy container aspect.";
          };
        };

        config = {
          dot.oci.secrets.caddy.enable = true;
          dot.caddy.global.email = lib.mkDefault acmeEmail;

          dot.containers.dataDirs = {
            caddy = {
              inherit (containers.owners.home) user group;
            };
            "caddy-config" = {
              inherit (containers.owners.home) user group;
            };
          };

          environment.etc."caddy/Caddyfile".text = lib.dot.mkCaddyfile {
            global = config.dot.caddy.global;
            routes = config.dot.caddy.routes;
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
              autoUpdate = "registry";
            };
            serviceConfig = {
              Restart = "always";
              RestartSec = "10s";
            };
          };
        };
      };
  };
}

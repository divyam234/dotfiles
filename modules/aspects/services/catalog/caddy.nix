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

          systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [
            "caddy"
            "caddy-config"
          ];

          environment.etc."caddy/Caddyfile".text = lib.dot.mkCaddyfile {
            global = config.dot.caddy.global;
            routes = config.dot.caddy.routes;
          };

          virtualisation.quadlet.containers.caddy = {
            autoStart = true;
            containerConfig = {
              image = "ghcr.io/tgdrive/caddy";
              networks = [ quadlet.networks.${lib.dot.containerNetwork}.ref ];
              environmentFiles = [ (lib.dot.containerEnvFile "caddy") ];
              publishPorts = [
                "80:80"
                "443:443"
                "443:443/udp"
              ];
              volumes = [
                "/etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro"
                "${lib.dot.containerDataDir "caddy"}:/data"
                "${lib.dot.containerDataDir "caddy-config"}:/config"
              ];
            };
            unitConfig = {
              After = [ "sops-install-secrets.service" ];
              Requires = [ "sops-install-secrets.service" ];
            };
            serviceConfig = {
              Restart = "always";
              RestartSec = "10s";
            };
          };

          networking.firewall.allowedTCPPorts = [
            80
            443
          ];
          networking.firewall.allowedUDPPorts = [ 443 ];
        };
      };
  };
}

{ den, ... }:
{
  den.aspects.pgdog =
    { host, ... }:
    let
      fqdn = "postgres.${host.domain}";
    in
    {
      caddyRoutes.pgdog-tls = {
        host = fqdn;
        access = "public";
        # Must stay DNS-only: Cloudflare proxying only speaks
        # HTTP on 443 and would break the `postgresql` ALPN handshake.
        proxied = false;
        encode = false;
        securityHeaders = false;
        extraConfig = ''
          respond "OK" 200
        '';
      };

      caddyLayer4Routes = [
        ''
          @tls-pgsql tls {
            alpn postgresql
            sni ${fqdn}
          }
          route @tls-pgsql {
            tls {
              # Required: PostgreSQL 17+ direct-TLS clients offer only
              # `postgresql` as ALPN (no h2/http/1.1). See
              # https://raw.githubusercontent.com/mholt/caddy-l4/refs/heads/master/docs/examples/postgres-over-tls.md
              connection_policy {
                alpn postgresql
              }
            }
            # Caddy terminates TLS here; plaintext stays on the isolated
            # svc podman network.
            proxy pgdog:6432
          }
        ''
      ];

      nixos =
        {
          config,
          containers,
          pkgs,
          ...
        }:
        let
          quadlet = config.virtualisation.quadlet;
          toml = pkgs.formats.toml { };
          pgdogConfig = {
            general = {
              host = "0.0.0.0";
              port = 6432;
              default_pool_size = 40;
              pooler_mode = "transaction";
              passthrough_auth = "enabled_plain";
              pub_sub_channel_size = 4096;
            };
            databases = [
              {
                name = "postgres";
                host = "postgres";
                port = 5432;
                database_name = "postgres";
                role = "primary";
              }
            ];
          };
          pgdogConfigFile = toml.generate "pgdog.toml" pgdogConfig;
        in
        {
          virtualisation.quadlet.containers.pgdog = {
            autoStart = true;
            containerConfig = {
              name = "pgdog";
              image = "ghcr.io/pgdogdev/pgdog";
              networks = [ quadlet.networks.${containers.networkName}.ref ];
              networkAliases = [ "pgdog" ];
              publishPorts = [ "6432:6432" ];
              volumes = [ "${pgdogConfigFile}:/pgdog/pgdog.toml:ro" ];
              autoUpdate = "registry";
            };
            unitConfig = {
              After = [ quadlet.containers.postgres.ref ];
              Requires = [ quadlet.containers.postgres.ref ];
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
}

{ den, ... }:
{
  den.aspects.teldrive = { host, ... }: {
    postgresDatabases.teldrive = { };

    caddyRoutes.teldrive = {
      host = "teldrive.${host.domain}";
      access = "tailnet";
      upstreams = [ "teldrive:8080" ];
    };

    nixos =
      {
        config,
        containers,
        secrets,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        sops.templates."teldrive.env" = secrets.mkTemplate {
          name = "teldrive.env";
          content = ''
            TELDRIVE_HTTP_ADDRESS=0.0.0.0:8080
            TELDRIVE_DATABASE_URL=postgres://${secrets.postgres.user}:${secrets.postgres.password}@pgdog:6432/postgres
            TELDRIVE_SECURITY_SIGNING_KEY=${secrets.teldrive.signing_key}
            TELDRIVE_SECURITY_DATA_KEY=${secrets.teldrive.data_key}
            TELDRIVE_ENCRYPTION_ACTIVE_KEY_VERSION=1
            TELDRIVE_ENCRYPTION_KEYS=1:${secrets.teldrive.encryption_key}
            TELDRIVE_TELEGRAM_MTPROXY_ADDRESS=mtproxy:443
            TELDRIVE_TELEGRAM_MTPROXY_SECRET=${secrets.mtproxy.secret}
            TELDRIVE_DATABASE_AUTO_MIGRATE_LEGACY=false
            TELDRIVE_TELEGRAM_DOWNLOAD_CLIENT_POOL=true
            TELDRIVE_TELEGRAM_DOWNLOAD_BOTS=4
            TELDRIVE_TELEGRAM_RATE_LIMIT=false
            TELDRIVE_SECURITY_ACCESS_TOKEN_TTL=24h
            TELDRIVE_SECURITY_REFRESH_TOKEN_TTL=8760h
          '';
        };

        virtualisation.quadlet.containers.teldrive = {
          autoStart = true;
          containerConfig = {
            name = "teldrive";
            image = "ghcr.io/tgdrive/teldrive:v2";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "teldrive" ];
            environmentFiles = [ "${containers.secretDir}/teldrive.env" ];
            autoUpdate = "registry";
          };
          unitConfig = {
            After = [
              quadlet.containers.postgres.ref
              quadlet.containers.mtproxy.ref
              "postgres-provision.service"
            ];
            Requires = [
              quadlet.containers.postgres.ref
              quadlet.containers.mtproxy.ref
              "postgres-provision.service"
            ];
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
}

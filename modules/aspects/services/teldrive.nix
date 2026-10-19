{ den, ... }:
{
  den.aspects.teldrive = { host, ... }: {
    nixosSecrets = [
      "postgres/user"
      "postgres/password"
      "teldrive/signing_key"
      "teldrive/data_key"
      "teldrive/encryption_key"
      "mtproxy/secret"
    ];

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
        dependencies = [
          quadlet.containers.postgres.ref
          "postgres-provision.service"
          quadlet.containers.mtproxy.ref
        ];
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
            TELDRIVE_JOBS_RUN_WORKERS=true
            TELDRIVE_TELEGRAM_MTPROXY_ADDRESS=mtproxy:443
            TELDRIVE_TELEGRAM_MTPROXY_SECRET=${secrets.mtproxy.secret}
            TELDRIVE_DATABASE_AUTO_MIGRATE_LEGACY=false
            TELDRIVE_TELEGRAM_DOWNLOAD_BOTS=4
            TELDRIVE_TELEGRAM_DOWNLOAD_CLIENT_POOL=true
            TELDRIVE_TELEGRAM_DOWNLOAD_READ_BUFFERS=32
            TELDRIVE_TELEGRAM_DOWNLOAD_READ_PARALLEL=4
            TELDRIVE_TELEGRAM_RATE_LIMIT=false
            TELDRIVE_TELEGRAM_MAX_RETRIES=30
            TELDRIVE_SECURITY_ACCESS_TOKEN_TTL=24h
            TELDRIVE_SECURITY_REFRESH_TOKEN_TTL=8760h
            TELDRIVE_LOGGING_LOG_FORMAT=text
          '';
        };

        virtualisation.quadlet.containers.teldrive = {
          containerConfig = {
            image = "ghcr.io/tgdrive/teldrive:2";
            networkAliases = [ "teldrive" ];
            environmentFiles = [ "${containers.secretDir}/teldrive.env" ];
          };
          unitConfig = {
            After = dependencies;
            Requires = dependencies;
          };
          serviceConfig = {
            MemoryMax = "2G";
            CPUQuota = "200%";
          };
        };
      };
  };
}

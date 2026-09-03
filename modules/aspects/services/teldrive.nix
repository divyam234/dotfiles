{ den, ... }:
{
  den.aspects.teldrive = { host, ... }: {
    caddyRoutes =
      if host.teldrive.exposeThroughCaddy then
        {
          teldrive = {
            host = "teldrive.${host.domain}";
            access = "tailnet";
            upstreams = [ "teldrive:8080" ];
          };
        }
      else
        { };

    nixos =
      {
        config,
        containers,
        secrets,
        lib,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
        cfg = host.teldrive;
        download = cfg.download;
        optionalEnv =
          name: value:
          lib.optionalString (value != null)
            "${name}=${if builtins.isBool value then lib.boolToString value else toString value}";
        localDatabase = cfg.databaseHost == "pgdog";
        databaseDependencies = lib.optionals localDatabase [
          quadlet.containers.postgres.ref
          "postgres-provision.service"
        ];
        remoteDatabaseDependencies = lib.optional (!localDatabase) "tailscale-autoconnect.service";
        mtproxyDependencies = lib.optional cfg.useMtproxy quadlet.containers.mtproxy.ref;
      in
      {
        sops.templates."teldrive.env" = secrets.mkTemplate {
          name = "teldrive.env";
          content = ''
            TELDRIVE_HTTP_ADDRESS=0.0.0.0:8080
            TELDRIVE_DATABASE_URL=postgres://${secrets.postgres.user}:${secrets.postgres.password}@${cfg.databaseHost}:6432/postgres
            TELDRIVE_SECURITY_SIGNING_KEY=${secrets.teldrive.signing_key}
            TELDRIVE_SECURITY_DATA_KEY=${secrets.teldrive.data_key}
            TELDRIVE_ENCRYPTION_ACTIVE_KEY_VERSION=1
            TELDRIVE_ENCRYPTION_KEYS=1:${secrets.teldrive.encryption_key}
            TELDRIVE_JOBS_RUN_WORKERS=${lib.boolToString cfg.runWorkers}
            ${lib.optionalString cfg.useMtproxy ''
              TELDRIVE_TELEGRAM_MTPROXY_ADDRESS=mtproxy:443
                          TELDRIVE_TELEGRAM_MTPROXY_SECRET=${secrets.mtproxy.secret}''}
            TELDRIVE_DATABASE_AUTO_MIGRATE_LEGACY=false
            ${optionalEnv "TELDRIVE_TELEGRAM_DOWNLOAD_BOTS" download.bots}
            ${optionalEnv "TELDRIVE_TELEGRAM_DOWNLOAD_CLIENT_POOL" download.clientPool}
            ${optionalEnv "TELDRIVE_TELEGRAM_DOWNLOAD_READ_BUFFERS" download.readBuffers}
            ${optionalEnv "TELDRIVE_TELEGRAM_DOWNLOAD_READ_PARALLEL" download.readParallel}
            TELDRIVE_TELEGRAM_RATE_LIMIT=false
            TELDRIVE_SECURITY_ACCESS_TOKEN_TTL=24h
            TELDRIVE_SECURITY_REFRESH_TOKEN_TTL=8760h
            TELDRIVE_LOGGING_LOG_FORMAT=text
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
            publishPorts = lib.optional (cfg.port != null) "${toString cfg.port}:8080";
            autoUpdate = "registry";
          };
          unitConfig = {
            After = databaseDependencies ++ remoteDatabaseDependencies ++ mtproxyDependencies;
            Requires = databaseDependencies ++ mtproxyDependencies;
            Wants = remoteDatabaseDependencies;
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

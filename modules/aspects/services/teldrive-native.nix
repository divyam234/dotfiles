{ den, inputs, ... }:
{
  den.aspects.teldrive-native = {
    nixosSecrets = [
      "postgres/user"
      "postgres/password"
      "teldrive/signing_key"
      "teldrive/data_key"
      "teldrive/encryption_key"
    ];

    nixos =
      {
        config,
        pkgs,
        secrets,
        ...
      }:
      {
        imports = [ inputs.teldrive.nixosModules.default ];

        sops.templates."teldrive.env" =
          (secrets.mkTemplate {
            name = "teldrive.env";
            path = "/run/secrets/teldrive.env";
            mode = "0400";
            content = ''
              TELDRIVE_DATABASE_URL=postgres://${secrets.postgres.user}:${secrets.postgres.password}@netcup:6432/postgres
              TELDRIVE_SECURITY_SIGNING_KEY=${secrets.teldrive.signing_key}
              TELDRIVE_SECURITY_DATA_KEY=${secrets.teldrive.data_key}
              TELDRIVE_ENCRYPTION_ACTIVE_KEY_VERSION=1
              TELDRIVE_ENCRYPTION_KEYS=1:${secrets.teldrive.encryption_key}
            '';
          })
          // {
            restartUnits = [ "teldrive.service" ];
          };

        services.teldrive = {
          enable = true;
          package = pkgs.teldrive-bin;
          environmentFile = config.sops.templates."teldrive.env".path;
          settings = {
            http.address = "127.0.0.1:8090";
            database.auto-migrate-legacy = false;
            jobs.run-workers = false;
            telegram = {
              download-bots = 4;
              download-client-pool = true;
              download-read-buffers = 32;
              download-read-parallel = 4;
              rate-limit = false;
              max-retries = 30;
            };
            security = {
              access-token-ttl = "24h";
              refresh-token-ttl = "8760h";
            };
          };
        };

        systemd.services.teldrive = {
          after = [ "tailscale-autoconnect.service" ];
          wants = [ "tailscale-autoconnect.service" ];
        };
      };
  };
}

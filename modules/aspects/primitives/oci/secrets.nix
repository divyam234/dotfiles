{ den, ... }:
{
  den.aspects.container-secrets = {
    includes = [ den.aspects.sops ];

    nixos =
      {
        config,
        lib,
        host,
        ...
      }:
      let
        cfg = config.dot.oci.secrets;
        secretsFile = host.secretsFile;
        anyEnabled = lib.any (enabled: enabled) [
          cfg.caddy.enable
          cfg.forgejo.enable
          cfg.gluetun.enable
          cfg.postgres.enable
          cfg.redis.enable
          cfg.vaultwarden.enable
        ];
        postgresCredentialsNeeded = lib.any (enabled: enabled) [
          cfg.forgejo.enable
          cfg.postgres.enable
          cfg.vaultwarden.enable
        ];
      in
      {
        options.dot.oci.secrets = {
          caddy.enable = lib.mkEnableOption "Caddy Cloudflare environment file";
          forgejo.enable = lib.mkEnableOption "Forgejo database environment file";
          gluetun.enable = lib.mkEnableOption "Gluetun VPN environment file";
          postgres.enable = lib.mkEnableOption "Postgres environment file";
          redis.enable = lib.mkEnableOption "Redis environment file";
          vaultwarden.enable = lib.mkEnableOption "Vaultwarden environment file";
        };

        config = {
          assertions = [
            {
              assertion = !anyEnabled || secretsFile != null;
              message = "Host ${host.name} enables OCI secret-backed containers but does not set host.secretsFile.";
            }
          ];

          sops.secrets = lib.mkIf (secretsFile != null) (
            lib.mkMerge [
              (lib.mkIf postgresCredentialsNeeded {
                "postgres/user".sopsFile = secretsFile;
                "postgres/password".sopsFile = secretsFile;
              })
              (lib.mkIf cfg.caddy.enable {
                "cloudflare/api_token".sopsFile = secretsFile;
              })
              (lib.mkIf cfg.gluetun.enable {
                "wireguard/private_key".sopsFile = secretsFile;
              })
              (lib.mkIf cfg.redis.enable {
                "redis/password".sopsFile = secretsFile;
              })
              (lib.mkIf cfg.vaultwarden.enable {
                "vaultwarden/admin_token".sopsFile = secretsFile;
              })
            ]
          );

          sops.templates = lib.mkIf (secretsFile != null) (
            lib.mkMerge [
              (lib.mkIf cfg.postgres.enable {
                "postgres.env" = {
                  path = lib.dot.containerEnvFile "postgres";
                  mode = "0440";
                  content = ''
                    POSTGRES_USER=${config.sops.placeholder."postgres/user"}
                    POSTGRES_PASSWORD=${config.sops.placeholder."postgres/password"}
                    POSTGRES_DB=postgres
                  '';
                };
              })

              (lib.mkIf cfg.gluetun.enable {
                "gluetun.env" = {
                  path = lib.dot.containerEnvFile "gluetun";
                  mode = "0440";
                  content = ''
                    VPN_SERVICE_PROVIDER=nordvpn
                    VPN_TYPE=wireguard
                    WIREGUARD_PRIVATE_KEY=${config.sops.placeholder."wireguard/private_key"}
                    SERVER_HOSTNAMES=nl885.nordvpn.com,nl886.nordvpn.com
                    HTTPPROXY=on
                    HTTPPROXY_LISTENING_ADDRESS=:3128
                    SOCKS5=on
                    SOCKS5_LISTENING_ADDRESS=:1081
                    FIREWALL_OUTBOUND_SUBNETS=100.64.0.0/10
                  '';
                };
              })

              (lib.mkIf cfg.redis.enable {
                "redis.env" = {
                  path = lib.dot.containerEnvFile "redis";
                  mode = "0440";
                  content = ''
                    REDIS_PASSWORD=${config.sops.placeholder."redis/password"}
                  '';
                };
              })

              (lib.mkIf cfg.caddy.enable {
                "caddy.env" = {
                  path = lib.dot.containerEnvFile "caddy";
                  mode = "0440";
                  content = ''
                    CLOUDFLARE_API_TOKEN=${config.sops.placeholder."cloudflare/api_token"}
                  '';
                };
              })

              (lib.mkIf cfg.forgejo.enable {
                "forgejo.env" = {
                  path = lib.dot.containerEnvFile "forgejo";
                  mode = "0440";
                  content = ''
                    FORGEJO__database__DB_TYPE=postgres
                    FORGEJO__database__HOST=pgdog:6432
                    FORGEJO__database__NAME=postgres
                    FORGEJO__database__USER=${config.sops.placeholder."postgres/user"}
                    FORGEJO__database__PASSWD=${config.sops.placeholder."postgres/password"}
                    FORGEJO__database__SCHEMA=forgejo
                    FORGEJO__database__SSL_MODE=disable
                  '';
                };
              })

              (lib.mkIf cfg.vaultwarden.enable {
                "vaultwarden.env" = {
                  path = lib.dot.containerEnvFile "vaultwarden";
                  mode = "0440";
                  content = ''
                    DOMAIN=https://vault.${host.domain}
                    ADMIN_TOKEN=${config.sops.placeholder."vaultwarden/admin_token"}
                    DATABASE_URL=postgres://${config.sops.placeholder."postgres/user"}:${
                      config.sops.placeholder."postgres/password"
                    }@postgres/postgres?application_name=bitwarden&options=-c%20search_path%3Dbitwarden
                  '';
                };
              })
            ]
          );
        };
      };
  };
}

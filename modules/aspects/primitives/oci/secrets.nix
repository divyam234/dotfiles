{ den, ... }:
{
  den.aspects.container-secrets = {
    includes = [ den.aspects.sops ];

    nixos =
      {
        config,
        ociSecrets,
        lib,
        host,
        secrets,
        ...
      }:
      let
        enabled = name: builtins.elem name (lib.flatten ociSecrets);
        containers.secretDir = "/run/secrets/container-env";
        anyEnabled = lib.any (enabled: enabled) [
          (enabled "caddy")
          (enabled "forgejo")
          (enabled "gluetun")
          (enabled "postgres")
          (enabled "redis")
          (enabled "vaultwarden")
        ];
        postgresCredentialsNeeded = lib.any (enabled: enabled) [
          (enabled "forgejo")
          (enabled "postgres")
          (enabled "vaultwarden")
        ];
      in
      {
        config = {
          assertions = [
            {
              assertion = !anyEnabled || host.secretsFile != null;
              message = "Host ${host.name} enables OCI secret-backed containers but does not set host.secretsFile.";
            }
          ];

          sops.secrets = lib.mkIf (host.secretsFile != null) (
            lib.mkMerge [
              (lib.mkIf postgresCredentialsNeeded {
                "postgres/user" = secrets.host host "postgres/user";
                "postgres/password" = secrets.host host "postgres/password";
              })
              (lib.mkIf (enabled "caddy") {
                "cloudflare/api_token" = secrets.common "cloudflare/api_token";
              })
              (lib.mkIf (enabled "gluetun") {
                "wireguard/private_key" = secrets.host host "wireguard/private_key";
              })
              (lib.mkIf (enabled "redis") {
                "redis/password" = secrets.host host "redis/password";
              })
              (lib.mkIf (enabled "vaultwarden") {
                "vaultwarden/admin_token" = secrets.host host "vaultwarden/admin_token";
              })
            ]
          );

          sops.templates = lib.mkIf (host.secretsFile != null) (
            lib.mkMerge [
              (lib.mkIf (enabled "postgres") {
                "postgres.env" = {
                  path = "${containers.secretDir}/postgres.env";
                  mode = "0440";
                  content = ''
                    POSTGRES_USER=${config.sops.placeholder."postgres/user"}
                    POSTGRES_PASSWORD=${config.sops.placeholder."postgres/password"}
                    POSTGRES_DB=postgres
                  '';
                };
              })

              (lib.mkIf (enabled "gluetun") {
                "gluetun.env" = {
                  path = "${containers.secretDir}/gluetun.env";
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

              (lib.mkIf (enabled "redis") {
                "redis.env" = {
                  path = "${containers.secretDir}/redis.env";
                  mode = "0440";
                  content = ''
                    REDIS_PASSWORD=${config.sops.placeholder."redis/password"}
                  '';
                };
              })

              (lib.mkIf (enabled "caddy") {
                "caddy.env" = {
                  path = "${containers.secretDir}/caddy.env";
                  mode = "0440";
                  content = ''
                    CLOUDFLARE_API_TOKEN=${config.sops.placeholder."cloudflare/api_token"}
                  '';
                };
              })

              (lib.mkIf (enabled "forgejo") {
                "forgejo.env" = {
                  path = "${containers.secretDir}/forgejo.env";
                  mode = "0440";
                  content = ''
                    FORGEJO__database__DB_TYPE=postgres
                    FORGEJO__database__HOST=pgdog:6432
                    FORGEJO__database__NAME=postgres
                    FORGEJO__database__USER=${config.sops.placeholder."postgres/user"}
                    FORGEJO__database__PASSWD=${config.sops.placeholder."postgres/password"}
                    FORGEJO__database__SCHEMA=forgejo
                    # FORGEJO__database__SSL_MODE=disable
                    # FORGEJO__server__DISABLE_SSH=false
                    # FORGEJO__server__START_SSH_SERVER=true
                    # FORGEJO__server__SSH_SERVER_USE_PROXY_PROTOCOL=false
                    # FORGEJO__server__SSH_PORT=443
                    # FORGEJO__server__SSH_LISTEN_PORT=2240
                  '';
                };
              })

              (lib.mkIf (enabled "vaultwarden") {
                "vaultwarden.env" = {
                  path = "${containers.secretDir}/vaultwarden.env";
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

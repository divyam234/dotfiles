{ den, ... }:
{
  den.aspects.container-secrets = {
    nixos =
      {
        config,
        lib,
        host,
        ...
      }:
      {
        sops.secrets = {
          "postgres/user".sopsFile = ../../../../hosts/netcup/secrets.yaml;
          "postgres/password".sopsFile = ../../../../hosts/netcup/secrets.yaml;
          "caddy/cloudflare_api_token".sopsFile = ../../../../hosts/netcup/secrets.yaml;
          "gluetun/vpn_private_key".sopsFile = ../../../../hosts/netcup/secrets.yaml;
          "gluetun/vpn_addresses".sopsFile = ../../../../hosts/netcup/secrets.yaml;
          "redis/password".sopsFile = ../../../../hosts/netcup/secrets.yaml;
          "vaultwarden/admin_token".sopsFile = ../../../../hosts/netcup/secrets.yaml;
        };

        sops.templates = {
          "postgres.env" = {
            path = lib.dot.containerEnvFile "postgres";
            mode = "0440";
            content = ''
              POSTGRES_USER=${config.sops.placeholder."postgres/user"}
              POSTGRES_PASSWORD=${config.sops.placeholder."postgres/password"}
              POSTGRES_DB=postgres
            '';
          };

          "gluetun.env" = {
            path = lib.dot.containerEnvFile "gluetun";
            mode = "0440";
            content = ''
              VPN_SERVICE_PROVIDER=nordvpn
              VPN_TYPE=wireguard
              WIREGUARD_PRIVATE_KEY=${config.sops.placeholder."gluetun/wireguard_private_key"}
              SERVER_HOSTNAMES=nl885.nordvpn.com,nl886.nordvpn.com
              httpProxy = "on";
              HTTPPROXY_LISTENING_ADDRESS=:3128
              FIREWALL_OUTBOUND_SUBNETS=100.64.0.0/10
            '';
          };

          "redis.env" = {
            path = lib.dot.containerEnvFile "redis";
            mode = "0440";
            content = ''
              REDIS_PASSWORD=${config.sops.placeholder."redis/password"}
            '';
          };

          "caddy.env" = {
            path = lib.dot.containerEnvFile "caddy";
            mode = "0440";
            content = ''
              CLOUDFLARE_API_TOKEN=${config.sops.placeholder."caddy/cloudflare_api_token"}
            '';
          };

          "forgejo.env" = {
            path = lib.dot.containerEnvFile "forgejo";
            mode = "0440";
            content = ''
              FORGEJO__database__DB_TYPE=postgres
              FORGEJO__DATABASE__HOST=pgdog:5432
              FORGEJO__database__NAME=postgres
              FORGEJO__database__USER=${config.sops.placeholder."postgres/user"}
              FORGEJO__database__PASSWD=${config.sops.placeholder."postgres/password"}
              FORGEJO__DATABASE__SCHEMA=forgejo
              FORGEJO__database__SSL_MODE=disable
            '';
          };

          "vaultwarden.env" = {
            path = lib.dot.containerEnvFile "vaultwarden";
            mode = "0440";
            content = ''
              DOMAIN=https://vault.${host.domain}
              DATABASE_URL=postgres://${config.sops.placeholder."postgres/user"}:${
                config.sops.placeholder."postgres/password"
              }@postgres/postgres?application_name=bitwarden&options=-c%20search_path%3Dbitwarden
            '';
          };

        };
      };
  };
}

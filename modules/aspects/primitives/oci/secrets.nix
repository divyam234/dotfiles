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
      let
        secretsFile = host.secretsFile;
        hasService = name: host.services.${name}.enable or false;
        hasAny = names: lib.any (n: hasService n) names;
      in
      {
        assertions = [
          {
            assertion = secretsFile != null;
            message = "Host ${host.name} enables container secrets but does not set host.secretsFile.";
          }
        ];

        sops.secrets = lib.mkIf (secretsFile != null) (
          let
            postgresNeeded = hasAny [ "postgres" "forgejo" "vaultwarden" ];
          in
          {
            "postgres/user".sopsFile = lib.mkIf postgresNeeded secretsFile;
            "postgres/password".sopsFile = lib.mkIf postgresNeeded secretsFile;
            "cloudflare/api_token".sopsFile = lib.mkIf (hasService "caddy") secretsFile;
            "wireguard/private_key".sopsFile = lib.mkIf (hasService "gluetun") secretsFile;
            "wireguard/addresses".sopsFile = lib.mkIf (hasService "gluetun") secretsFile;
            "redis/password".sopsFile = lib.mkIf (hasService "redis") secretsFile;
            "vaultwarden/admin_token".sopsFile = lib.mkIf (hasService "vaultwarden") secretsFile;
          }
        );

        sops.templates = lib.mkIf (secretsFile != null) {
          "postgres.env" = lib.mkIf (hasService "postgres") {
            path = lib.dot.containerEnvFile "postgres";
            mode = "0440";
            content = ''
              POSTGRES_USER=${config.sops.placeholder."postgres/user"}
              POSTGRES_PASSWORD=${config.sops.placeholder."postgres/password"}
              POSTGRES_DB=postgres
            '';
          };

          "gluetun.env" = lib.mkIf (hasService "gluetun") {
            path = lib.dot.containerEnvFile "gluetun";
            mode = "0440";
            content = ''
              VPN_SERVICE_PROVIDER=nordvpn
              VPN_TYPE=wireguard
              WIREGUARD_PRIVATE_KEY=${config.sops.placeholder."wireguard/private_key"}
              SERVER_HOSTNAMES=nl885.nordvpn.com,nl886.nordvpn.com
              httpProxy = "on";
              HTTPPROXY_LISTENING_ADDRESS=:3128
              FIREWALL_OUTBOUND_SUBNETS=100.64.0.0/10
            '';
          };

          "redis.env" = lib.mkIf (hasService "redis") {
            path = lib.dot.containerEnvFile "redis";
            mode = "0440";
            content = ''
              REDIS_PASSWORD=${config.sops.placeholder."redis/password"}
            '';
          };

          "caddy.env" = lib.mkIf (hasService "caddy") {
            path = lib.dot.containerEnvFile "caddy";
            mode = "0440";
            content = ''
              CLOUDFLARE_API_TOKEN=${config.sops.placeholder."cloudflare/api_token"}
            '';
          };

          "forgejo.env" = lib.mkIf (hasService "forgejo") {
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

          "vaultwarden.env" = lib.mkIf (hasService "vaultwarden") {
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

        };
      };
  };
}

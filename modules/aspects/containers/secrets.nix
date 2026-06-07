{ den, ... }:
{
  den.aspects.container-secrets = {
    nixos = { config, lib, host, ... }: {
      sops.secrets = {
        "postgres/user".sopsFile = ../../../hosts/netcup/secrets.yaml;
        "postgres/password".sopsFile = ../../../hosts/netcup/secrets.yaml;
        "valkey/password".sopsFile = ../../../hosts/netcup/secrets.yaml;
        "caddy/cloudflare_api_token".sopsFile = ../../../hosts/netcup/secrets.yaml;
        "atticd/token_hs256_secret_base64".sopsFile = ../../../hosts/netcup/secrets.yaml;
        "vaultwarden/admin_token".sopsFile = ../../../hosts/netcup/secrets.yaml;
        "gotify/default_user_password".sopsFile = ../../../hosts/netcup/secrets.yaml;
        "restic/password".sopsFile = ../../../hosts/netcup/secrets.yaml;
        "restic/repository".sopsFile = ../../../hosts/netcup/secrets.yaml;
        "restic/rclone_conf".sopsFile = ../../../hosts/netcup/secrets.yaml;
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

        "valkey.env" = {
          path = lib.dot.containerEnvFile "valkey";
          mode = "0440";
          content = ''
            VALKEY_PASSWORD=${config.sops.placeholder."valkey/password"}
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
            FORGEJO__server__DOMAIN=git.${host.domain}
            FORGEJO__server__ROOT_URL=https://git.${host.domain}/
            FORGEJO__server__HTTP_PORT=3000
            FORGEJO__database__DB_TYPE=postgres
            FORGEJO__database__HOST=postgres:5432
            FORGEJO__database__NAME=postgres
            FORGEJO__database__USER=${config.sops.placeholder."postgres/user"}
            FORGEJO__database__PASSWD=${config.sops.placeholder."postgres/password"}
            FORGEJO__database__SSL_MODE=disable
          '';
        };

        "atuin.env" = {
          path = lib.dot.containerEnvFile "atuin";
          mode = "0440";
          content = ''
            ATUIN_HOST=0.0.0.0
            ATUIN_PORT=8888
            ATUIN_OPEN_REGISTRATION=false
            ATUIN_DB_URI=postgres://${config.sops.placeholder."postgres/user"}:${config.sops.placeholder."postgres/password"}@postgres:5432/postgres
          '';
        };

        "atticd.env" = {
          path = lib.dot.containerEnvFile "atticd";
          mode = "0440";
          content = ''
            ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64=${config.sops.placeholder."atticd/token_hs256_secret_base64"}
          '';
        };

        "vaultwarden.env" = {
          path = lib.dot.containerEnvFile "vaultwarden";
          mode = "0440";
          content = ''
            DOMAIN=https://vault.${host.domain}
            DATABASE_URL=postgres://${config.sops.placeholder."postgres/user"}:${config.sops.placeholder."postgres/password"}@postgres:5432/postgres
            ADMIN_TOKEN=${config.sops.placeholder."vaultwarden/admin_token"}
            WEBSOCKET_ENABLED=true
          '';
        };

        "gotify.env" = {
          path = lib.dot.containerEnvFile "gotify";
          mode = "0440";
          content = ''
            GOTIFY_DEFAULTUSER_PASS=${config.sops.placeholder."gotify/default_user_password"}
          '';
        };
      };
    };
  };
}

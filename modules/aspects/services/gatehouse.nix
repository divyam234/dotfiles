{ den, ... }:
{
  den.aspects.gatehouse = { host, ... }: {
    nixosSecrets = [
      "gatehouse/admin_email"
      "gatehouse/admin_password"
      "gatehouse/better_auth_secret"
      "postgres/user"
      "postgres/password"
    ];

    caddyRoutes.gatehouse = {
      host = "auth.${host.domain}";
      access = "public";
      proxied = true;
      upstreams = [ "gatehouse:8080" ];
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
        sops.templates."gatehouse.env" = secrets.mkTemplate {
          name = "gatehouse.env";
          content = ''
            NODE_ENV=production
            PORT=8080
            APP_NAME=Gatehouse
            BETTER_AUTH_SECRET=${secrets.gatehouse.better_auth_secret}
            BETTER_AUTH_URL=https://auth.${host.domain}
            DATABASE_URL=postgres://${secrets.postgres.user}:${secrets.postgres.password}@postgres:5432/postgres
            DATABASE_POOL_MAX=20
            RUN_MIGRATIONS=true
            TRUST_PROXY_HEADERS=true
            TRUSTED_IP_HEADERS=CF-Connecting-IP,X-Real-IP,X-Forwarded-For
            CORS_ORIGINS=https://auth.${host.domain},https://stash.${host.domain}
            TRUSTED_ORIGINS=https://*.${host.domain}
            COOKIE_DOMAIN=.${host.domain}
            REQUIRE_EMAIL_VERIFICATION=false
            ENABLE_HIBP=true
            ALLOW_DEVELOPMENT_MAIL_LOG=false
            SEED_ADMIN_EMAIL=${secrets.gatehouse.admin_email}
            SEED_ADMIN_PASSWORD=${secrets.gatehouse.admin_password}
            SEED_DEFAULT_APPLICATION=true
            DEFAULT_APPLICATION_HOST=stash.${host.domain}
            DEFAULT_APPLICATION_UPSTREAM=http://stash:8080
          '';
        };

        virtualisation.quadlet.containers = {
          gatehouse = {
            containerConfig = {
              image = "ghcr.io/divyam234/gatehouse:latest";
              networkAliases = [ "gatehouse" ];
              environmentFiles = [ "${containers.secretDir}/gatehouse.env" ];
            };
            unitConfig = {
              After = [
                quadlet.containers.postgres.ref
              ];
              Requires = [
                quadlet.containers.postgres.ref
              ];
            };
            serviceConfig = {
              MemoryMax = "1G";
              CPUQuota = "100%";
            };
          };

          caddy.unitConfig = {
            After = [ quadlet.containers.gatehouse.ref ];
            Wants = [ quadlet.containers.gatehouse.ref ];
          };
        };
      };
  };
}

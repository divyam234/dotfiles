{ den, ... }:
{
  den.aspects.gateauth = { host, ... }: {
    nixosSecrets = [
      "gateauth/admin_email"
      "gateauth/admin_password"
      "gateauth/better_auth_secret"
      "postgres/user"
      "postgres/password"
    ];

    caddyRoutes.gateauth = {
      host = "auth.${host.domain}";
      access = "public";
      proxied = true;
      upstreams = [ "gateauth:8080" ];
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
        sops.templates."gateauth.env" = secrets.mkTemplate {
          name = "gateauth.env";
          content = ''
            NODE_ENV=production
            PORT=8080
            APP_NAME=Gateauth
            BETTER_AUTH_SECRET=${secrets.gateauth.better_auth_secret}
            BETTER_AUTH_URL=https://auth.${host.domain}
            DATABASE_URL=postgres://${secrets.postgres.user}:${secrets.postgres.password}@pgdog:6432/postgres
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
            SEED_ADMIN_EMAIL=${secrets.gateauth.admin_email}
            SEED_ADMIN_PASSWORD=${secrets.gateauth.admin_password}
            SEED_DEFAULT_APPLICATION=true
            DEFAULT_APPLICATION_HOST=stash.${host.domain}
            DEFAULT_APPLICATION_UPSTREAM=http://stash:8080
          '';
        };

        virtualisation.quadlet.containers = {
          gateauth = {
            containerConfig = {
              image = "ghcr.io/divyam234/gateauth:latest";
              networkAliases = [ "gateauth" ];
              environmentFiles = [ "${containers.secretDir}/gateauth.env" ];
            };
            unitConfig = {
              After = [ quadlet.containers.pgdog.ref ];
              Requires = [ quadlet.containers.pgdog.ref ];
            };
            serviceConfig = {
              MemoryMax = "1G";
              CPUQuota = "100%";
            };
          };

          caddy.unitConfig = {
            After = [ quadlet.containers.gateauth.ref ];
            Wants = [ quadlet.containers.gateauth.ref ];
          };
        };
      };
  };
}

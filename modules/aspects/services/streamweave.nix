{ den, ... }:
{
  den.aspects.streamweave = { host, ... }: {
    nixosSecrets = [
      "postgres/user"
      "postgres/password"
      "streamweave/admin_token"
      "streamweave/master_key"
    ];

    caddyRoutes.streamweave = {
      host = "streamweave.${host.domain}";
      access = "public";
      proxied = true;
      encode = false;
      cacheStatic = false;
      upstreams = [ "streamweave:8080" ];
    };

    nixos =
      {
        config,
        secrets,
        ...
      }:
      let
        image = "ghcr.io/divyam234/streamweave:latest";
      in
      {
        virtualisation.quadlet.containers.streamweave = {
          secretEnvironment = {
            PRODUCTION = "true";
            HTTP_ADDR = ":8080";
            DATABASE_URL = "postgres://${secrets.postgres.user}:${secrets.postgres.password}@pgdog:6432/postgres?sslmode=disable";
            DATABASE_SCHEMA = "streamweave";
            MASTER_KEY = secrets.streamweave.master_key;
            ADMIN_TOKEN = secrets.streamweave.admin_token;
          };
          containerConfig = {
            inherit image;
            networkAliases = [ "streamweave" ];
          };
          unitConfig = {
            After = [ config.virtualisation.quadlet.containers.pgdog.ref ];
            Requires = [ config.virtualisation.quadlet.containers.pgdog.ref ];
          };
          serviceConfig = {
            MemoryMax = "1G";
            CPUQuota = "200%";
          };
        };
      };
  };
}

{ den, ... }:
{
  den.aspects.streamweave = { host, ... }: {
    nixosSecrets = [
      "postgres/user"
      "postgres/password"
      "streamweave/admin_token"
      "streamweave/master_key"
    ];

    postgresSchemas.streamweave = { };

    caddyRoutes.streamweave = {
      host = "streamweave.${host.domain}";
      access = "public";
      proxied = false;
      encode = false;
      cacheStatic = false;
      upstreams = [ "streamweave:8080" ];
    };

    nixos =
      {
        config,
        containers,
        pkgs,
        secrets,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
        image = "ghcr.io/divyam234/streamweave:latest";
        envFile = "${containers.secretDir}/streamweave.env";
        migrate = pkgs.writeShellScript "streamweave-migrate" ''
          set -eu
          ${pkgs.podman}/bin/podman pull ${image}
          ${pkgs.podman}/bin/podman run --rm --pull=never \
            --network ${containers.networkName} \
            --env-file ${envFile} \
            --entrypoint /usr/local/bin/streamweave-migrate \
            ${image}
        '';
      in
      {
        sops.templates."streamweave.env" = secrets.mkTemplate {
          name = "streamweave.env";
          content = ''
            PRODUCTION=true
            HTTP_ADDR=:8080
            DATABASE_URL=postgres://${secrets.postgres.user}:${secrets.postgres.password}@pgdog:6432/postgres?sslmode=disable
            DATABASE_SCHEMA=streamweave
            MASTER_KEY=${secrets.streamweave.master_key}
            ADMIN_TOKEN=${secrets.streamweave.admin_token}
          '';
        };

        virtualisation.quadlet.containers.streamweave = {
          containerConfig = {
            inherit image;
            networkAliases = [ "streamweave" ];
            environmentFiles = [ envFile ];
          };
          unitConfig = {
            After = [
              quadlet.containers.pgdog.ref
              "postgres-provision.service"
            ];
            Requires = [
              quadlet.containers.pgdog.ref
              "postgres-provision.service"
            ];
          };
          serviceConfig = {
            ExecStartPre = migrate;
            MemoryMax = "1G";
            CPUQuota = "200%";
          };
        };
      };
  };
}

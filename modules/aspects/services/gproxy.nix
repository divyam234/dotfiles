{ den, ... }:
{
  den.aspects.gproxy = { user, host, ... }: {
    nixosSecrets = [
      "postgres/user"
      "postgres/password"
      "gproxy/admin_password"
      "gproxy/master_key"
    ];

    postgresSchemas.gproxy = { };
    caddyRoutes = {
      gproxy = {
        host = "gproxy.${host.domain}";
        access = "tailnet";
        upstreams = [ "gproxy:8787" ];
      };
    };

    nixos =
      {
        config,
        containers,
        pkgs,
        user,
        secrets,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        sops.templates."gproxy.env" = secrets.mkTemplate {
          name = "gproxy.env";
          content = ''
            GPROXY_HOST=0.0.0.0
            GPROXY_PORT=8787
            GPROXY_PERSISTENCE=db
            GPROXY_DSN=postgres://${secrets.postgres.user}:${secrets.postgres.password}@postgres:5432/postgres?application_name=gproxy&options=-c%20search_path%3Dgproxy
            GPROXY_ADMIN_PASSWORD=${secrets.gproxy.admin_password}
            GPROXY_MASTER_KEY=${secrets.gproxy.master_key}
          '';
        };

        virtualisation.quadlet.containers.gproxy = {
          containerConfig = {
            image = "ghcr.io/leenhawk/gproxy:latest";
            networkAliases = [ "gproxy" ];
            environmentFiles = [ "${containers.secretDir}/gproxy.env" ];
            volumes = [ "${containers.dataRoot}/gproxy:/app/data" ];
          };
          unitConfig = {
            After = [
              quadlet.containers.postgres.ref
              "postgres-provision.service"
            ];
            Requires = [
              quadlet.containers.postgres.ref
              "postgres-provision.service"
            ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/gproxy";
            MemoryMax = "512M";
            CPUQuota = "100%";
          };
        };
      };
  };
}

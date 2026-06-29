{ den, ... }:
{
  den.aspects.gproxy = { user, host, ... }: {
    postgresSchemas.gproxy = { };
    caddyRoutes = {
      gproxy = {
        host = "gproxy.${host.domain}";
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
        sops.templates."gproxy.env" = {
          path = "${containers.secretDir}/gproxy.env";
          mode = "0440";
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
          autoStart = true;
          containerConfig = {
            name = "gproxy";
            image = "ghcr.io/leenhawk/gproxy:latest";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "gproxy" ];
            environmentFiles = [ "${containers.secretDir}/gproxy.env" ];
            publishPorts = [ "8787:8787" ];
            volumes = [ "${containers.dataRoot}/gproxy:/app/data" ];
            autoUpdate = "registry";
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
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            MemoryMax = "512M";
            CPUQuota = "100%";
          };
        };
      };
  };
}

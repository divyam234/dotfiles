{ den, ... }:
{
  den.aspects.postgres = _: {
    includes = [ den.aspects.oci-service ];
    containerDataDirs.postgres = {
      user = "999";
      group = "999";
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
        sops.templates."postgres.env" = {
          path = "${containers.secretDir}/postgres.env";
          mode = "0440";
          content = ''
            POSTGRES_USER=${secrets.postgres.user}
            POSTGRES_PASSWORD=${secrets.postgres.password}
            POSTGRES_DB=postgres
          '';
        };

        virtualisation.quadlet.containers.postgres = {
          autoStart = true;
          containerConfig = {
            name = "postgres";
            image = "ghcr.io/tgdrive/postgres:18";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "postgres" ];
            environmentFiles = [ "${containers.secretDir}/postgres.env" ];
            volumes = [ "${containers.dataRoot}/postgres:/var/lib/postgresql" ];
            healthCmd = "pg_isready -U $POSTGRES_USER -d postgres || exit 1";
            autoUpdate = "registry";
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            MemoryMax = "2G";
            CPUQuota = "200%";
          };
        };
      };
  };
}

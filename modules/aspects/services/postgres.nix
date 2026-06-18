{ den, ... }:
{
  den.aspects.postgres = { ... }: {
    includes = [ den.aspects.oci-service ];
    ociSecrets = [ "postgres" ];
    containerDataDirs.postgres = {
      user = "999";
      group = "999";
    };

    nixos =
      { config, containers, ... }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
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

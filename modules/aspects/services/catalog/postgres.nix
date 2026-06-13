{ den, ... }:
{
  den.aspects.postgres = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { config, ... }:
      let
        quadlet = config.virtualisation.quadlet;
        containers = config.dot.containers;
      in
      {
        dot.oci.secrets.postgres.enable = true;
        dot.containers.dataDirs.postgres = {
          inherit (containers.owners.postgres) user group;
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
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };
      };
  };
}

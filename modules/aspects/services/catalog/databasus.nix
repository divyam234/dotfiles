{ den, ... }:
{
  den.aspects.databasus = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { config, ... }:
      let
        quadlet = config.virtualisation.quadlet;
        containers = config.dot.containers;
      in
      {
        dot.containers.dataDirs.databasus = {
          inherit (containers.owners.home) user group;
        };
        virtualisation.quadlet.containers.databasus = {
          autoStart = false;
          containerConfig = {
            name = "databasus";
            image = "databasus/databasus";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "databasus" ];
            volumes = [ "${containers.dataRoot}/databasus:/databasus-data" ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };
      };
  };
}

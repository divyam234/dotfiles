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
            image = "docker.io/databasus/databasus";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "databasus" ];
            volumes = [ "${containers.dataRoot}/databasus:/databasus-data" ];
            autoUpdate = "registry";
          };
          serviceConfig = {
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

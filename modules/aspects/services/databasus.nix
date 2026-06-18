{ den, ... }:
{
  den.aspects.databasus = { user, ... }: {
    includes = [ den.aspects.oci-service ];
    containerDataDirs.databasus = {
      user = user.userName;
      group = "users";
    };

    nixos =
      { config, containers, ... }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
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

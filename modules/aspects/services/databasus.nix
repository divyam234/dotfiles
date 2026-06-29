{ den, ... }:
{
  den.aspects.databasus = { user, ... }: {
    nixos =
      {
        config,
        containers,
        pkgs,
        ...
      }:
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
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/databasus";
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

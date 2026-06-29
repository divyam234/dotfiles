{ den, ... }:
{
  den.aspects.camofox = { user, ... }: {
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
        virtualisation.quadlet.containers.camofox-browser = {
          autoStart = true;
          containerConfig = {
            name = "camofox-browser";
            image = "ghcr.io/jo-inc/camofox-browser";
            healthCmd = "none";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "camofox-browser" ];
            environments = {
              CAMOFOX_PORT = "9377";
              ENABLE_VNC = "1";
              VNC_BIND = "0.0.0.0";
              VNC_RESOLUTION = "1920x1080";
              MAX_OLD_SPACE_SIZE = "2048";
            };
            publishPorts = [ "127.0.0.1:9377:9377" ];
            volumes = [ "${containers.dataRoot}/camofox:/root/.camofox" ];
            autoUpdate = "registry";
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/camofox";
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            MemoryMax = "3G";
            CPUQuota = "200%";
          };
        };
      };
  };
}

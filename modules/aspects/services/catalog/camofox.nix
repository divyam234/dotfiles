{ den, ... }:
{
  den.aspects.camofox = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { config, ... }:
      let
        quadlet = config.virtualisation.quadlet;
        containers = config.dot.containers;
      in
      {
        dot.containers.dataDirs.camofox = { };
        virtualisation.quadlet.containers.camofox-browser = {
          autoStart = false;
          containerConfig = {
            name = "camofox-browser";
            image = "ghcr.io/tgdrive/camofox-browser";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "camofox-browser" ];
            environments = {
              CAMOFOX_PORT = "9377";
              CAMOFOX_AUTH_MODE = "disabled";
            };
            publishPorts = [ "127.0.0.1:9377:9377" ];
            volumes = [ "${containers.dataRoot}/camofox:/home/node/.camofox" ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };
      };
  };
}

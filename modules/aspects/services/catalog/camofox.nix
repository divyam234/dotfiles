{ den, ... }:
{
  den.aspects.camofox = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { config, lib, ... }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "camofox" ];
        virtualisation.quadlet.containers.camofox-browser = {
          autoStart = false;
          containerConfig = {
            image = "ghcr.io/tgdrive/camofox-browser";
            networks = [ quadlet.networks.${lib.dot.containerNetwork}.ref ];
            environments = {
              CAMOFOX_PORT = "9377";
              CAMOFOX_AUTH_MODE = "disabled";
            };
            publishPorts = [ "127.0.0.1:9377:9377" ];
            volumes = [ "${lib.dot.containerDataDir "camofox"}:/home/node/.camofox" ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };
      };
  };
}

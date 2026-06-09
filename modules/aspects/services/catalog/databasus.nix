{ den, ... }:
{
  den.aspects.databasus = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { config, lib, ... }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "databasus" ];
        virtualisation.quadlet.containers.databasus = {
          autoStart = false;
          containerConfig = {
            image = "databasus/databasus";
            networks = [ quadlet.networks.${lib.dot.containerNetwork}.ref ];
            volumes = [ "${lib.dot.containerDataDir "databasus"}:/databasus-data" ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };
      };
  };
}

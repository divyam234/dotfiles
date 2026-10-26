{ den, ... }:
{
  den.aspects.gost.nixos =
    { config, ... }:
    let
      gluetun = config.virtualisation.quadlet.containers.gluetun.ref;
    in
    {
      virtualisation.quadlet.containers.gost = {
        containerConfig = {
          image = "docker.io/gogost/gost:latest";
          networks = [ "container:gluetun" ];
          environments.GOST_LOGGER_LEVEL = "error";
          exec = [
            "-L"
            "http://:3128"
          ];
        };
        unitConfig = {
          After = [ gluetun ];
          Requires = [ gluetun ];
          PartOf = [ gluetun ];
        };
        serviceConfig = {
          CPUQuota = "50%";
        };
      };
    };
}

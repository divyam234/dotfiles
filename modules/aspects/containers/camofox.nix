{ den, ... }:
{
  den.aspects.camofox = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { lib, ... }:
      {
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "camofox" ];
        virtualisation.oci-containers.containers.camofox-browser = lib.dot.mkOci "camofox-browser" {
          image = "ghcr.io/redf0x1/camofox-browser";
          environment = {
            CAMOFOX_PORT = "9377";
            CAMOFOX_AUTH_MODE = "disabled";
          };
          ports = [ "127.0.0.1:9377:9377" ];
          volumes = [ "${lib.dot.containerDataDir "camofox"}:/home/node/.camofox" ];
        };
        systemd.services.podman-camofox-browser = lib.dot.mkContainerDeps "camofox-browser" [ ];
      };
  };
}

{ den, ... }:
{
  den.aspects.databasus = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { lib, ... }:
      {
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "databasus" ];
        virtualisation.oci-containers.containers.databasus = lib.dot.mkOci "databasus" {
          image = "databasus/databasus";
          volumes = [ "${lib.dot.containerDataDir "databasus"}:/databasus-data" ];
        };
        systemd.services.podman-databasus = lib.dot.mkContainerDeps "databasus" [ ];
      };
  };
}

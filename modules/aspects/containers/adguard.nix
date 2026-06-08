{ den, ... }:
{
  den.aspects.adguard = {
    includes = [ den.aspects.oci-service ];

    nixos =
      { lib, ... }:
      {
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "adguard-cli" ];

        virtualisation.oci-containers.containers.adguard-cli = lib.dot.mkOci "adguard-cli" {
          image = "ghcr.io/tgdrive/adguard-cli";
          networkMode = "container:gluetun";
          dependsOn = [ "gluetun" ];
          cmd = [
            "adguard-cli"
            "start"
            "--no-fork"
          ];
          volumes = [ "${lib.dot.containerDataDir "adguard-cli"}:/root/.local/share/adguard-cli" ];
        };

        systemd.services.podman-adguard-cli = lib.dot.mkContainerDeps "adguard-cli" [ "gluetun" ];
      };
  };
}

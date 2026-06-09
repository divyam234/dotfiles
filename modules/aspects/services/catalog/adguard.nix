{ den, ... }:
{
  den.aspects.adguard = {
    includes = [ den.aspects.oci-service ];

    nixos =
      { config, lib, ... }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "adguard-cli" ];

        virtualisation.quadlet.containers.adguard-cli = {
          autoStart = true;
          containerConfig = {
            image = "ghcr.io/tgdrive/adguard-cli";
            networks = [ "container:gluetun" ];
            exec = [
              "adguard-cli"
              "start"
              "--no-fork"
            ];
            volumes = [ "${lib.dot.containerDataDir "adguard-cli"}:/root/.local/share/adguard-cli" ];
          };
          unitConfig = {
            After = [ quadlet.containers.gluetun.ref ];
            Requires = [ quadlet.containers.gluetun.ref ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };
      };
  };
}

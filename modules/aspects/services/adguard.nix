{ den, ... }:
{
  den.aspects.adguard = {
    includes = [ den.aspects.oci-service ];

    nixos =
      { config, lib, ... }:
      let
        quadlet = config.virtualisation.quadlet;
        containers = config.dot.containers;
      in
      {
        dot.caddy.global.layer4Routes = [
          ''
            @s5 socks5
            route @s5 {
              proxy gluetun:1081
            }
          ''
        ];

        dot.containers.dataDirs."adguard-cli" = {
          inherit (containers.owners.home) user group;
        };

        virtualisation.quadlet.containers.adguard-cli = {
          autoStart = true;
          containerConfig = {
            name = "adguard-cli";
            image = "ghcr.io/tgdrive/adguard-cli";
            networks = [ "container:gluetun" ];
            exec = [
              "adguard-cli"
              "start"
              "--no-fork"
            ];
            volumes = [ "${containers.dataRoot}/adguard-cli:/root/.local/share/adguard-cli" ];
            autoUpdate = "registry";
          };
          unitConfig = {
            After = [ quadlet.containers.gluetun.ref ];
            Requires = [ quadlet.containers.gluetun.ref ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            MemoryMax = "256M";
            CPUQuota = "50%";
          };
        };
      };
  };
}

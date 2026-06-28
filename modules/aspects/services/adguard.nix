{ den, ... }:
{
  den.aspects.adguard = { user, ... }: {
    caddyLayer4Routes = [
      ''
        @s5 socks5
        route @s5 {
          proxy gluetun:1081
        }
      ''
    ];
    containerDataDirs."adguard-cli" = {
      user = user.userName;
      group = "users";
    };

    nixos =
      { config, containers, ... }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
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

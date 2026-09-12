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
    nixos =
      {
        config,
        containers,
        pkgs,
        user,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        virtualisation.quadlet.containers.adguard-cli = {
          containerConfig = {
            image = "ghcr.io/tgdrive/adguard-cli";
            networks = [ "container:gluetun" ];
            addCapabilities = [ "NET_ADMIN" ];
            exec = [
              "adguard-cli"
              "start"
              "--no-fork"
            ];
            volumes = [ "${containers.dataRoot}/adguard-cli:/root/.local/share/adguard-cli" ];
          };
          unitConfig = {
            After = [ quadlet.containers.gluetun.ref ];
            Requires = [ quadlet.containers.gluetun.ref ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/adguard-cli";
            MemoryMax = "256M";
            CPUQuota = "50%";
          };
        };
      };
  };
}

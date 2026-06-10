{ den, ... }:
{
  den.aspects.gluetun = {
    includes = [ den.aspects.oci-service ];

    nixos =
      { config, lib, ... }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        boot.kernelModules = [ "tun" ];
        dot.oci.secrets.gluetun.enable = true;
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "gluetun" ];

        virtualisation.quadlet.containers.gluetun = {
          autoStart = true;
          containerConfig = {
            image = "qmcgaw/gluetun";
            networks = [ quadlet.networks.${lib.dot.containerNetwork}.ref ];
            environmentFiles = [ (lib.dot.containerEnvFile "gluetun") ];
            addCapabilities = [ "NET_ADMIN" ];
            devices = [ "/dev/net/tun:/dev/net/tun" ];
            sysctl = {
              "net.ipv4.conf.all.src_valid_mark" = "1";
              "net.ipv6.conf.all.disable_ipv6" = "1";
            };
            publishPorts = [
              "127.0.0.1:3128:3128" # HTTP proxy
              "127.0.0.1:1081:1081" # SOCKS5 proxy (for Caddy layer4)
            ];
            volumes = [ "${lib.dot.containerDataDir "gluetun"}:/gluetun" ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };
      };
  };
}

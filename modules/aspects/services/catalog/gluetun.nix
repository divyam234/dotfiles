{ den, ... }:
{
  den.aspects.gluetun = {
    includes = [ den.aspects.oci-service ];

    nixos =
      { config, lib, ... }:
      let
        quadlet = config.virtualisation.quadlet;
        containers = config.dot.containers;
      in
      {
        boot.kernelModules = [ "tun" ];
        dot.oci.secrets.gluetun.enable = true;
        dot.containers.dataDirs.gluetun = {
          inherit (containers.owners.home) user group;
        };

        virtualisation.quadlet.containers.gluetun = {
          autoStart = true;
          containerConfig = {
            name = "gluetun";
            image = "docker.io/qmcgaw/gluetun";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "gluetun" ];
            environmentFiles = [ "${containers.secretDir}/gluetun.env" ];
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
            volumes = [ "${containers.dataRoot}/gluetun:/gluetun" ];
            autoUpdate = "registry";
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };
      };
  };
}

{ den, ... }:
{
  den.aspects.gluetun = { user, ... }: {
    includes = [ den.aspects.oci-service ];
    ociSecrets = [ "gluetun" ];
    containerDataDirs.gluetun = {
      user = user.userName;
      group = "users";
    };

    nixos =
      { config, containers, ... }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        boot.kernelModules = [ "tun" ];

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
            NoNewPrivileges = true;
            MemoryMax = "512M";
            CPUQuota = "100%";
          };
        };
      };
  };
}

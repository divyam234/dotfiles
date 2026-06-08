{ den, ... }:
{
  den.aspects.gluetun = {
    includes = [ den.aspects.oci-service ];

    nixos =
      { lib, ... }:
      {
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "gluetun" ];

        virtualisation.oci-containers.containers.gluetun = lib.dot.mkOci "gluetun" {
          image = "qmcgaw/gluetun";
          environmentFiles = [ (lib.dot.containerEnvFile "gluetun") ];
          extraOptions = [
            "--cap-add=NET_ADMIN"
            "--device=/dev/net/tun:/dev/net/tun"
            "--sysctl=net.ipv4.conf.all.src_valid_mark=1"
            "--sysctl=net.ipv6.conf.all.disable_ipv6=1"
          ];
          ports = [
            "127.0.0.1:3128:3128" # HTTP proxy
            "127.0.0.1:1081:1081" # SOCKS5 proxy (for Caddy layer4)
          ];
          volumes = [ "${lib.dot.containerDataDir "gluetun"}:/gluetun" ];
        };

        systemd.services.podman-gluetun = lib.dot.mkContainerDeps "gluetun" [ ];
      };
  };
}

{ den, ... }:
{
  den.aspects.gluetun = { user, ... }: {
    containerDataDirs.gluetun = {
      user = user.userName;
      group = "users";
    };

    nixos =
      {
        config,
        containers,
        secrets,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        sops.templates."gluetun.env" = {
          path = "${containers.secretDir}/gluetun.env";
          mode = "0440";
          content = ''
            VPN_SERVICE_PROVIDER=nordvpn
            VPN_TYPE=wireguard
            WIREGUARD_PRIVATE_KEY=${secrets.nordvpn.private_key}
            SERVER_HOSTNAMES=nl885.nordvpn.com,nl886.nordvpn.com
            HTTPPROXY=on
            HTTPPROXY_LISTENING_ADDRESS=:3128
            FIREWALL_OUTBOUND_SUBNETS=100.64.0.0/10
          '';
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
            NoNewPrivileges = true;
            MemoryMax = "512M";
            CPUQuota = "100%";
          };
        };
      };
  };
}

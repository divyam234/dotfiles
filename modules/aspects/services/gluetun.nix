{ den, ... }:
{
  den.aspects.gluetun = { user, ... }: {
    nixosSecrets = [ "nordvpn/private_key" ];

    nixos =
      {
        containers,
        pkgs,
        secrets,
        ...
      }:
      {
        sops.templates."gluetun.env" = secrets.mkTemplate {
          name = "gluetun.env";
          content = ''
            VPN_SERVICE_PROVIDER=nordvpn
            VPN_TYPE=wireguard
            WIREGUARD_PRIVATE_KEY=${secrets.nordvpn.private_key}
            SERVER_HOSTNAMES=nl1181.nordvpn.com,nl1173.nordvpn.com
            HTTPPROXY=on
            HTTPPROXY_LISTENING_ADDRESS=:3128
            FIREWALL_OUTBOUND_SUBNETS=100.64.0.0/10
          '';
        };

        virtualisation.quadlet.containers.gluetun = {
          containerConfig = {
            image = "docker.io/qmcgaw/gluetun";
            networkAliases = [ "gluetun" ];
            environmentFiles = [ "${containers.secretDir}/gluetun.env" ];
            addCapabilities = [ "NET_ADMIN" ];
            devices = [ "/dev/net/tun:/dev/net/tun" ];
            sysctl = {
              "net.ipv4.conf.all.src_valid_mark" = "1";
              "net.ipv6.conf.all.disable_ipv6" = "1";
            };
            publishPorts = [
              "3128:3128"
              "3129:3129"
              "1081:1081"
            ];
            volumes = [ "${containers.dataRoot}/gluetun:/gluetun" ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/gluetun";
            MemoryMax = "512M";
            CPUQuota = "100%";
          };
        };
      };
  };
}

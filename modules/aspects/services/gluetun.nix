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
        virtualisation.quadlet.containers.gluetun = {
          secretEnvironment.WIREGUARD_PRIVATE_KEY = secrets.nordvpn.private_key;
          containerConfig = {
            image = "docker.io/qmcgaw/gluetun";
            networkAliases = [ "gluetun" ];
            environments = {
              VPN_SERVICE_PROVIDER = "nordvpn";
              VPN_TYPE = "wireguard";
              SERVER_HOSTNAMES = "nl850.nordvpn.com,nl1258.nordvpn.com";
              FIREWALL_INPUT_PORTS = "3128";
              FIREWALL_OUTBOUND_SUBNETS = "100.64.0.0/10";
            };
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
          };
        };
      };
  };
}

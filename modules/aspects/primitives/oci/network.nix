{ den, ... }:
{
  den.aspects.container-network = {
    nixos =
      { pkgs, ... }:
      let
        networkName = "svc";
      in
      {
        virtualisation.quadlet.networks.${networkName} = {
          networkConfig = {
            name = networkName;
            driver = "bridge";
            interfaceName = "br-${networkName}";
            subnets = [ "10.89.0.0/24" ];
          };
          serviceConfig.ExecStop = "-${pkgs.podman}/bin/podman network rm ${networkName}";
        };

        networking.firewall.interfaces."br-${networkName}".allowedUDPPorts = [ 53 ];
      };
  };
}

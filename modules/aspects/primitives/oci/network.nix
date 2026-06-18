{ den, ... }:
{
  den.aspects.container-network = {
    nixos =
      { ... }:
      let
        networkName = "svc";
      in
      {
        virtualisation.quadlet.networks.${networkName}.networkConfig = {
          name = networkName;
          driver = "bridge";
          interfaceName = "br-${networkName}";
        };

        networking.firewall.interfaces."br-${networkName}".allowedUDPPorts = [ 53 ];
      };
  };
}

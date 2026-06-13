{ den, ... }:
{
  den.aspects.container-network = {
    nixos =
      { config, ... }:
      let
        cfg = config.dot.containers;
      in
      {
        virtualisation.quadlet.networks.${cfg.networkName}.networkConfig = {
          name = cfg.networkName;
          driver = "bridge";
          interfaceName = "br-${cfg.networkName}";
        };

        networking.firewall.interfaces."br-${cfg.networkName}".allowedUDPPorts = [ 53 ];
      };
  };
}

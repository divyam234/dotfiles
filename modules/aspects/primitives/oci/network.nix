{ den, ... }:
{
  den.aspects.container-network = {
    nixos =
      { lib, ... }:
      {
        virtualisation.quadlet.networks.${lib.dot.containerNetwork}.networkConfig = { };
      };
  };
}

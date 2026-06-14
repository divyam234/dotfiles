{ den, ... }:
{
  den.aspects.firewall = {
    nixos =
      { ... }:
      {
        networking.firewall = {
          enable = true;
          allowedTCPPorts = [
            2222
            80
            443
          ];
          allowedUDPPorts = [ 443 ];
        };
      };
  };
}

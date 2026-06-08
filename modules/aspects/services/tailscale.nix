{ den, ... }:
{
  den.aspects.tailscale = {
    nixos =
      { ... }:
      {
        services.tailscale.enable = true;
        services.tailscale.useRoutingFeatures = "server";
        networking.firewall = {
          checkReversePath = "loose";
          trustedInterfaces = [ "tailscale0" ];
          allowedUDPPorts = [ 41641 ];
        };
      };
  };
}

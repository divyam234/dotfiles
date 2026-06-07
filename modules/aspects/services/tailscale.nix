
{ den, ... }:
{
  den.aspects.tailscale = {
    nixos = { ... }: {
      services.tailscale.enable = true;
      networking.firewall.trustedInterfaces = [ "tailscale0" ];
    };
  };
}

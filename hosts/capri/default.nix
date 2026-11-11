{ den, ... }:
{
  den.aspects.capri = {
    includes = [
      den.aspects.common
      den.aspects.security-base
      den.aspects.tailscale
      den.aspects.server
      den.aspects.home-manager-policy
      den.aspects.droidspaces
    ];

    nixos.system.stateVersion = "26.05";
  };
}

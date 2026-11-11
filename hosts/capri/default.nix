{ den, lib, ... }:
{
  den.aspects.capri = {
    includes = [
      den.aspects.common
      den.aspects.security-base
      den.aspects.tailscale
      den.aspects.server
      den.aspects.home-manager-policy
      den.aspects.droidspaces
      den.aspects.teldrive-native
    ];

    nixos = {
      system.stateVersion = "26.05";
      services.teldrive.settings.http.address = lib.mkForce "0.0.0.0:8090";
      services.teldrive.user = "root";
      services.teldrive.group = "root";
    };
  };
}

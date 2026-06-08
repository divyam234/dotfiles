{ den, ... }:
{
  den.aspects.netcup = {
    nixos =
      { host, pkgs, ... }:
      {
        imports = [
          ./hardware-configuration.nix
          ./boot.nix
          ./networking.nix
        ];
        services.qemuGuest.enable = true;
        networking.domain = host.domain;
        system.stateVersion = "25.11";
      };
  };
}

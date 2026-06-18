{ den, ... }:
{
  den.aspects.netcup = {
    nixos =
      { host, ... }:
      {
        imports = [
          ./hardware-configuration.nix
          ./boot.nix
          ./networking.nix
        ];

        services.qemuGuest.enable = true;
        networking.domain = host.domain;
        system.stateVersion = "26.05";
      };
  };
}

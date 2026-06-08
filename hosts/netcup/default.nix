{ den, ... }:
{
  den.aspects.netcup = {
    nixos =
      { ... }:
      {
        imports = [
          ./hardware-configuration.nix
          ./networking.nix
        ];

        system.stateVersion = "25.11";
      };
  };
}

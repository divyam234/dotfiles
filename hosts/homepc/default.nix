{ den, ... }:
{
  den.aspects.homepc = {
    nixos =
      { ... }:
      {
        imports = [
          ./hardware-configuration.nix
          ./disko.nix
        ];

        system.stateVersion = "25.11";
      };
  };
}

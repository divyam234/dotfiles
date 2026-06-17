{ den, ... }:
{
  den.aspects.laptop = {
    nixos = _: {
      imports = [
        ./hardware-configuration.nix
        ./boot.nix
      ];

      system.stateVersion = "26.05";
    };
  };
}

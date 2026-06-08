{ den, ... }:
{
  den.aspects.laptop = {
    nixos =
      { pkgs, ... }:
      {
        imports = [
          ./hardware-configuration.nix
          ./boot.nix
        ];

        system.stateVersion = "25.11";
      };
  };
}

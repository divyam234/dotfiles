{ den, ... }:
{
  den.aspects.laptop = {
    nixos =
      { pkgs, ... }:
      {
        imports = [
          ./hardware-configuration.nix
          ./disko.nix
        ];

        boot = {
          loader = {
            systemd-boot.enable = true;
            efi.canTouchEfiVariables = true;
            timeout = 3;
          };
          kernelPackages = pkgs.linuxPackages_latest;
        };

        system.stateVersion = "25.11";
      };
  };
}

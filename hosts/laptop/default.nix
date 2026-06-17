{ den, inputs, ... }:
{
  den.aspects.laptop = {
    nixos = _: {
      imports = [
        inputs.nixos-facter-modules.nixosModules.facter
        ./hardware-configuration.nix
        ./boot.nix
        ./networking.nix
        ./disko.nix
      ];

      facter.reportPath = ./facter.json;
      system.stateVersion = "26.05";
    };
  };
}

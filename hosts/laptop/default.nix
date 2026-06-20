{ den, inputs, ... }:
{
  flake-file.inputs.nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

  den.aspects.laptop = {
    nixos = _: {
      imports = [
        inputs.nixos-facter-modules.nixosModules.facter
        ./hardware-configuration.nix
        ./boot.nix
        ./graphics.nix
        ./networking.nix
        ./disko.nix
      ];

      facter.reportPath = ./facter.json;
      fileSystems."/run/media/bhunter/Drive" = {
        device = "/dev/disk/by-id/ata-ST1000LM048-2E7172_WL18LWDC-part1";
        fsType = "ext4";
        options = [
          "nofail"
          "x-systemd.automount"
        ];
      };
      system.stateVersion = "26.05";
    };
  };
}

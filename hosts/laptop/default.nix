{ den, inputs, ... }:
{
  flake-file.inputs.nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
  flake-file.inputs.nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

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
      fileSystems."/mnt/drive" = {
        device = "/dev/disk/by-id/ata-ST1000LM048-2E7172_WL18LWDC-part1";
        fsType = "ext4";
        options = [
          "nofail"
          "x-systemd.automount"
          "x-systemd.idle-timeout=10min"
        ];
      };
      system.stateVersion = "26.05";
    };
  };
}

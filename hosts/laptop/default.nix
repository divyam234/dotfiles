{ den, inputs, ... }:
{
  flake-file.inputs.cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
  flake-file.inputs.nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

  den.aspects.laptop = {
    includes = [
      den.aspects.common
      den.aspects.sops
      den.aspects.security-base
      den.aspects.workstation
      den.aspects.btrfs
      den.aspects.oci-runtime
      den.aspects.tailscale
    ];

    nixos = _: {
      imports = [
        inputs.nixos-facter-modules.nixosModules.facter
        ./hardware-configuration.nix
        ./boot.nix
        ./graphics.nix
        ./networking.nix
        ./disko.nix
        ./msi-ec/kmod.nix
      ];

      facter.reportPath = ./facter.json;
      fileSystems."/mnt/drive" = {
        device = "/dev/disk/by-id/ata-ST1000LM048-2E7172_WL18LWDC-part1";
        fsType = "ext4";
        options = [
          "nofail"
          "x-systemd.automount"
          "x-gvfs-show"
        ];
      };
      system.stateVersion = "26.05";
    };
  };
}

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

    nixos =
      { pkgs, ... }:
      {
        imports = [
          inputs.nixos-facter-modules.nixosModules.facter
          ./graphics.nix
          ./networking.nix
          ./disko.nix
          ./msi-ec/kmod.nix
        ];
        boot.loader = {
          systemd-boot.enable = true;
          systemd-boot.configurationLimit = 3;
          efi.canTouchEfiVariables = true;
          timeout = 3;
        };
        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-x86_64-v3;
        facter.reportPath = ./facter.json;
        fileSystems."/mnt/drive" = {
          device = "/dev/disk/by-id/ata-ST1000LM048-2E7172_WL18LWDC-part1";
          fsType = "ext4";
          options = [
            "nofail"
            "x-systemd.automount"
            "x-gvfs-show"
            "noatime"
          ];
        };
        system.stateVersion = "26.05";
      };
  };
}

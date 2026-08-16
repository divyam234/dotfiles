{ den, inputs, ... }:
{
  flake-file.inputs.cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

  den.aspects.laptop = {
    includes = [
      den.aspects.common
      den.aspects.sops
      den.aspects.boot-policy
      den.aspects.facter
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
          ./graphics.nix
          ./networking.nix
          ./disko.nix
          ./msi-ec/kmod.nix
        ];
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
        security.pki.certificateFiles = [ ./adguard.pem ];
        system.stateVersion = "26.05";
      };
  };
}

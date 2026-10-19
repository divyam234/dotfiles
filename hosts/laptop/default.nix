{ den, ... }:
{
  den.aspects.laptop = {
    includes = [
      den.aspects.base
      den.aspects.workstation
      den.aspects.cachyos-kernel
      den.aspects.btrfs
      den.aspects.oci-base
      den.aspects.container-network
    ];

    nixos = {
      imports = [
        ./graphics.nix
        ./networking.nix
        ./disko.nix
        ./msi-ec/kmod.nix
      ];
      facter.reportPath = ./facter.json;
      hardware.i2c.enable = true;
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

    homeManager = { pkgs, ... }: {
      home.packages = [ pkgs.mcontrolcenter ];
    };
  };

}

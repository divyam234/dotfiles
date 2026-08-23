{ den, ... }:
{
  den.aspects.homelab = {
    includes = [
      den.aspects.infra-host
      den.aspects.librespot
    ];
    nixos =
      { ... }:
      {
        imports = [
          ./disko.nix
          ./networking.nix
        ];
        hardware.graphics.enable = true;
        fileSystems."/mnt/drive" = {
          device = "/dev/disk/by-id/ata-ST500LT012-1DG142_WBY3EXQ5-part1";
          fsType = "ext4";
          options = [
            "nofail"
            "x-systemd.automount"
            "noatime"
          ];
        };
        fileSystems."/mnt/external" = {
          device = "/dev/disk/by-id/usb-Samsung_M3_Portable_97EF7DF80600006F-0:0-part1";
          fsType = "ext4";
          options = [
            "nofail"
            "x-systemd.automount"
            "noatime"
          ];
        };
        facter.reportPath = ./facter.json;
        system.stateVersion = "26.05";
      };
  };
}

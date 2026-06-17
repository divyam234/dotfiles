{ ... }:
let
  commonMountOptions = [
    "compress=zstd"
    "noatime"
    "ssd"
    "discard=async"
    "space_cache=v2"
  ];
in
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/ata-Samsung_SSD_860_EVO_M.2_250GB_S413NX0KA09386Y";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [
              "-f"
              "-L"
              "nixos"
            ];
            subvolumes = {
              "@root" = {
                mountpoint = "/";
                mountOptions = commonMountOptions;
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = commonMountOptions;
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = commonMountOptions;
              };
              "@persist" = {
                mountpoint = "/persist";
                mountOptions = commonMountOptions;
              };
              "@log" = {
                mountpoint = "/var/log";
                mountOptions = commonMountOptions;
              };
              "@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = commonMountOptions;
              };
            };
          };
        };
      };
    };
  };
}

# Replace with generated output from:
#   sudo nixos-generate-config --show-hardware-config
{ modulesPath, ... }:
{
  imports = [ ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [
    "kvm-amd"
    "kvm-intel"
  ];
  boot.extraModulePackages = [ ];

  # Declared by disko during fresh install.
  # Defined here explicitly so flake evaluation passes (disko's fileSystems
  # are not visible to nix flake check).
  fileSystems."/" = {
    device = "/dev/disk/by-partlabel/nixos-root";
    fsType = "btrfs";
    options = [ "subvol=@root" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/disk-main-ESP";
    fsType = "vfat";
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-partlabel/nixos-root";
    fsType = "btrfs";
    options = [ "subvol=@nix" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-partlabel/nixos-root";
    fsType = "btrfs";
    options = [ "subvol=@home" ];
  };
}

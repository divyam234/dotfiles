
# Replace with generated output from:
#   sudo nixos-generate-config --show-hardware-config
{ modulesPath, ... }:
{
  imports = [ ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Disko declares filesystems on fresh install.
  # If you do not use disko, replace this file with real generated mounts.
}

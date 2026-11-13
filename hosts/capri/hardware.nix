{
  lib,
  pkgs,
  ...
}:
let
  kernel = pkgs.callPackage ../../packages/capri/kernel { };
in
{
  # Use NixOS's standard U-Boot/extlinux loader. /boot lives on the root
  # filesystem; no EFI partition or Android GPT boundary changes are needed.
  boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor kernel);
  # The battery driver detects JK50 vs Power via DT; no charging kernel parameters.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  # Verified over ADB on this XT2127-4: userdata is mmcblk0p77. This declares
  # its future native filesystem; it does not format the current Android data.
  fileSystems."/" = {
    device = "/dev/disk/by-partuuid/f6eb68be-3488-aaba-703b-eb107625d212";
    fsType = "ext4";
  };

  # Compiled from the Power-specific DT source, not an Android vendor DTBO.
  hardware.deviceTree = {
    enable = true;
    name = "qcom/sm4250-motorola-capri-power.dtb";
  };

  # The handset uses built-in Qualcomm MMC, eMMC and ext4 drivers. The stock
  # x86-oriented initrd module list is inappropriate for this kernel.
  boot.initrd.includeDefaultModules = false;
  boot.initrd.systemd.tpm2.enable = false;
}

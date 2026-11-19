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
  boot = {
    kernelPackages = lib.mkForce (pkgs.linuxPackagesFor kernel);
    # Native PMI632 SMB5/QGauge are enabled by the Capri Power DT, no charge boot flags.
    loader = {
      grub.enable = lib.mkForce false;
      systemd-boot.enable = lib.mkForce false;
      generic-extlinux-compatible = {
        enable = true;
        configurationLimit = 5;
      };
      efi.canTouchEfiVariables = false;
    };

    # The handset uses built-in Qualcomm MMC, eMMC and ext4 drivers.
    initrd = {
      includeDefaultModules = false;
      # EXT support adds ext2, but Capri only has built-in EXT4_FS=y.
      availableKernelModules.ext2 = lib.mkForce false;
      systemd.tpm2.enable = false;
    };
  };

  # The native NixOS root lives in the former Android userdata partition
  # (eMMC mmcblk0p77). U-Boot does not boot from the removable microSD.
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_EMMC";
    fsType = "ext4";
  };

  # Compiled from the Power-specific DT source, not an Android vendor DTBO.
  hardware.deviceTree = {
    enable = true;
    name = "qcom/sm4250-motorola-capri-power.dtb";
  };

}

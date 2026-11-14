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
  # Native PMI632 SMB5/QGauge are enabled by the Capri Power DT, no charge boot flags.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.loader.generic-extlinux-compatible.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = false;

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

  # The handset uses built-in Qualcomm MMC, eMMC and ext4 drivers. The stock
  # x86-oriented initrd module list is inappropriate for this kernel.
  boot.initrd.includeDefaultModules = false;
  # NixOS's EXT initrd support adds ext2 even when only ext4 is mounted.
  # Capri has built-in EXT4_FS=y but no separate ext2 module; retain strict
  # module checking rather than allowing missing modules globally.
  boot.initrd.availableKernelModules.ext2 = lib.mkForce false;
  boot.initrd.systemd.tpm2.enable = false;

  # Temporary early-boot diagnostics for the first native microSD boot.
  # No console login or root password is required; output goes to the LCD.
  boot.initrd.systemd.services.capri-mmc-diagnostics = {
    description = "Show Capri microSD probe failures on boot console";
    wantedBy = [ "initrd.target" ];
    after = [ "systemd-udev-trigger.service" ];
    path = with pkgs; [
      coreutils
      gnugrep
      util-linux
    ];
    serviceConfig = {
      Type = "simple";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    script = ''
      for delay in 15 45; do
        sleep "$delay"
        echo "======= CAPRI MMC DIAGNOSTICS ======="
        echo "MMC hosts:"
        ls -l /sys/class/mmc_host/ || true
        echo "Block devices:"
        ls -l /sys/class/block/ || true
        echo "Detected rootfs labels:"
        ls -l /dev/disk/by-label/ || true
        echo "Kernel MMC and dependency probes:"
        dmesg | grep -iE 'mmc|sdhc|sdcc|card.det|pinctrl|regulat|rpmpd|interconnect|defer|probe' | tail -n 45 || true
        echo "======= END CAPRI MMC DIAGNOSTICS ======="
      done
    '';
  };
}

{
  android-tools,
  bison,
  buildUBoot,
  cpio,
  dtc,
  fetchFromGitHub,
  flex,
  gnutls,
  gzip,
  openssl,
  runCommand,
  xxd,
}:
let
  source = fetchFromGitHub {
    owner = "u-boot";
    repo = "u-boot";
    rev = "ece349ade2973e220f524ce59e59711cc919263f";
    hash = "sha256-MJf4+MifD7Bzb2Fz11lIgFOaiAPgSbFnbM0Q3k5xWwQ=";
  };

  uboot = buildUBoot {
    version = "2026.07";
    src = source;
    defconfig = "qcom_defconfig";
    nativeBuildInputs = [
      bison
      flex
      gnutls
      openssl
      xxd
    ];
    extraPatches = [
      ../patches/0001-uboot-motorola-capri-upstream-v2026.07.patch
      ../patches/0002-uboot-bootflow-explicit-partition.patch
    ];
    preConfigure = ''
      cp ${./default.env} board/qualcomm/motorola-capri.env
    '';
    postConfigure = ''
      make motorola-capri.config
      # Keep the boot path read-only even though the source patch also
      # exposes optional filesystem/GPT write commands.
      cat >> .config <<'EOF'
      CONFIG_BOOTSTD=y
      CONFIG_BOOTMETH_EXTLINUX=y
      CONFIG_CMD_BOOTFLOW=y
      CONFIG_CMD_BOOTFLOW_FULL=y
      CONFIG_CMD_BOOTI=y
      CONFIG_SUPPORT_RAW_INITRD=y
      CONFIG_CMD_EXT4=y
      CONFIG_FS_EXT4=y
      # CONFIG_MMC_WRITE is not set
      # CONFIG_FAT_WRITE is not set
      # CONFIG_EXT4_WRITE is not set
      # CONFIG_CMD_EXT4_WRITE is not set
      # CONFIG_CMD_GPT is not set
      # CONFIG_CMD_SAVEENV is not set
      # CONFIG_CMD_ERASEENV is not set
      # CONFIG_MMC_HW_PARTITIONING is not set
      # CONFIG_SUPPORT_EMMC_BOOT is not set
      # CONFIG_SUPPORT_EMMC_RPMB is not set
      # CONFIG_CMD_MMC_RPMB is not set
      # CONFIG_CMD_BKOPS_ENABLE is not set
      # CONFIG_USB_FUNCTION_FASTBOOT is not set
      # CONFIG_FASTBOOT_FLASH is not set
      # CONFIG_USB_FUNCTION_MASS_STORAGE is not set
      # CONFIG_USB_MASS_STORAGE is not set
      # CONFIG_CMD_USB_MASS_STORAGE is not set
      # CONFIG_DFU is not set
      # CONFIG_DFU_MMC is not set
      # CONFIG_DFU_SCSI is not set
      # CONFIG_CMD_DFU is not set
      # CONFIG_EFI_HAVE_CAPSULE_SUPPORT is not set
      # CONFIG_EFI_RUNTIME_UPDATE_CAPSULE is not set
      # CONFIG_EFI_CAPSULE_ON_DISK is not set
      # CONFIG_EFI_CAPSULE_FIRMWARE_RAW is not set
      # CONFIG_EFI_VARIABLE_FILE_STORE is not set
      # CONFIG_EFI_VARIABLE_SF_STORE is not set
      # CONFIG_EFI_MM_COMM_TEE is not set
      EOF
      make olddefconfig
    '';
    buildFlags = [
      "u-boot.bin"
      "u-boot.dtb"
      "binary_size_check"
      "init_sp_bss_offset_check"
    ];
    filesToInstall = [
      "u-boot.bin"
      "u-boot.dtb"
      ".config"
    ];
  };

  bootImage =
    runCommand "capri-uboot-android-v3-boot-image"
      {
        nativeBuildInputs = [
          android-tools
          cpio
          dtc
          gzip
        ];
        passthru = { inherit uboot; };
      }
      ''
        set -euo pipefail

        # Enforce read-only storage access and direct extlinux Linux boot.
        for option in \
          ARM64 MOTOROLA_CAPRI OF_SEPARATE OF_BOARD \
          LINUX_KERNEL_IMAGE_HEADER POSITION_INDEPENDENT \
          INIT_SP_RELATIVE SAVE_PREV_BL_FDT_ADDR \
          MMC MMC_SDHCI_MSM BOOTSTD BOOTMETH_EXTLINUX \
          CMD_BOOTFLOW CMD_BOOTFLOW_FULL CMD_BOOTI SUPPORT_RAW_INITRD \
          FS_EXT4 CMD_EXT4 PARTITION_UUIDS \
          ENV_IS_NOWHERE EFI_VARIABLE_NO_STORE; do
          grep -qx "CONFIG_''${option}=y" ${uboot}/.config
        done
        for option in \
          MMC_WRITE FAT_WRITE EXT4_WRITE CMD_SAVEENV CMD_ERASEENV \
          MMC_HW_PARTITIONING SUPPORT_EMMC_BOOT SUPPORT_EMMC_RPMB \
          CMD_MMC_RPMB CMD_BKOPS_ENABLE FASTBOOT_FLASH \
          USB_FUNCTION_FASTBOOT USB_FUNCTION_MASS_STORAGE DFU \
          EFI_HAVE_CAPSULE_SUPPORT EFI_CAPSULE_ON_DISK \
          EFI_VARIABLE_FILE_STORE EFI_VARIABLE_SF_STORE \
          EFI_MM_COMM_TEE ENV_IS_IN_MMC OF_OMIT_DTB; do
          if grep -qx "CONFIG_''${option}=y" ${uboot}/.config; then
            echo "Unsafe U-Boot configuration: ''${option}" >&2
            exit 1
          fi
        done
        if grep -Eq '^CONFIG_ENV_IS_IN_[A-Z_]+=y$' ${uboot}/.config; then
          echo "U-Boot must not persist its environment to storage" >&2
          exit 1
        fi

        test "$(fdtget -t x ${uboot}/u-boot.dtb / qcom,board-id)" = "500 b200"
        mkdir -p "$out"
        printf "%s" "" | cpio -o -H newc 2>/dev/null | gzip -n > empty-initramfs.gz

        mkbootimg \
          --header_version 3 \
          --kernel ${uboot}/u-boot.bin \
          --ramdisk empty-initramfs.gz \
          --cmdline capri.uboot=extlinux \
          --output "$out/boot-uboot-capri-v3.img"

        test "$(od -An -tu4 -j 40 -N 4 "$out/boot-uboot-capri-v3.img" | tr -d ' ')" = 3
        test "$(head -c 8 "$out/boot-uboot-capri-v3.img")" = "ANDROID!"
        ln -s ${uboot}/u-boot.bin "$out/u-boot.bin"
        ln -s ${uboot}/u-boot.dtb "$out/u-boot.dtb"
      '';
in
{
  inherit uboot bootImage;
}

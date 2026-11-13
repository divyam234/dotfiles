{
  buildLinux,
  fetchFromGitHub,
  lib,
  python3,
  features ? { },
  randstructSeed ? "",
  structuredExtraConfig ? { },
  ...
}@args:
let
  source = fetchFromGitHub {
    owner = "michaelmcallister";
    repo = "linux-motorola-capri";
    rev = "232c314e8909dd77395b2c553e7dda2232e4a4cc";
    hash = "sha256-NgSc1kU16RJHptdtQQxZmThk9DBzSAPAfOW7vybRs6o=";
  };

  kernel = buildLinux {
    pname = "linux-capri";
    version = "7.2.9";
    modDirVersion = "7.2.9-capri";
    src = source;
    # Start with the standard ARM64/NixOS configuration, not the stripped
    # handset defconfig. Keep device-specific requirements explicit below.
    defconfig = "defconfig";
    enableCommonConfig = true;
    autoModules = true;
    ignoreConfigErrors = false;
    structuredExtraConfig =
      with lib.kernel;
      {
        # Preserve Motorola's boot handoff and early built-in hardware path.
        ARCH_QCOM = yes;
        ARM64_MOTOROLA_CAPRI_BOOT = yes;
        ARM64_VA_BITS_39 = yes;
        NR_CPUS = lib.mkForce (freeform "8");
        RELOCATABLE = yes;
        LOCALVERSION = freeform "-capri";
        LOCALVERSION_AUTO = no;
        EFI = yes;
        EFI_STUB = yes;
        EFI_PARTITION = yes;
        BLK_DEV_INITRD = yes;
        RD_GZIP = yes;
        RD_ZSTD = yes;
        VT = yes;
        VT_CONSOLE = yes;
        VT_HW_CONSOLE_BINDING = yes;
        FRAMEBUFFER_CONSOLE = yes;
        INPUT_EVDEV = yes;
        INPUT_UINPUT = yes;

        # Native PMI632 SMB5 charging, QGauge and battery thermistor.
        POWER_SUPPLY = yes;
        IIO = yes;
        THERMAL = yes;
        CHARGER_QCOM_SMB2 = yes;
        BATTERY_QCOM_QG = yes;
        GENERIC_ADC_THERMAL = yes;
        NVMEM_SPMI_SDAM = yes;
        DRM_MSM = yes;
        DRM_MSM_DSI_14NM_PHY = yes;
        DRM_PANEL_MOTOROLA_CAPRI_DJN = yes;
        BACKLIGHT_CLASS_DEVICE = yes;
        FRAMEBUFFER_CONSOLE_ROTATION = yes;
        TOUCHSCREEN_NOVATEK_CAPRI = module;
        INPUT_PM8941_PWRKEY = yes;

        # Root storage and its clocks, regulators, interconnect and IOMMU.
        MMC = yes;
        RPMB = yes; # A modular RPMB backend caps MMC_BLOCK at module too.
        MMC_BLOCK = yes;
        MMC_SDHCI = yes;
        MMC_SDHCI_PLTFM = yes;
        MMC_SDHCI_MSM = yes;
        EXT4_FS = yes;
        PINCTRL_SM6115 = yes;
        PINCTRL_QCOM_SPMI_PMIC = yes;
        SPMI = yes;
        MFD_QCOM_RPM = yes;
        MFD_SPMI_PMIC = yes;
        REGULATOR_FIXED_VOLTAGE = yes;
        REGULATOR_QCOM_SMD_RPM = yes;
        REGULATOR_QCOM_SPMI = yes;
        REGULATOR_QCOM_USB_VBUS = yes;
        COMMON_CLK_QCOM = yes;
        QCOM_CLK_RPM = yes;
        QCOM_CLK_SMD_RPM = yes;
        SM_GCC_6115 = yes;
        SM_DISPCC_6115 = yes;
        SM_GPUCC_6115 = yes;
        INTERCONNECT_QCOM = yes;
        INTERCONNECT_QCOM_SM6115 = yes;
        ARM_SMMU = yes;
        ARM_SMMU_DISABLE_BYPASS_BY_DEFAULT = no;
        QCOM_IOMMU = yes;
        QCOM_SMEM = yes;
        QCOM_SMD_RPM = yes;
        QCOM_SMP2P = yes;
        QCOM_RPMPD = yes;
        QCOM_GENI_SE = yes;
        I2C_QCOM_GENI = yes;
        SPI_QCOM_GENI = yes;
        HWSPINLOCK_QCOM = yes;
        QCOM_APCS_IPC = yes;
        QCOM_IPCC = yes;
        QCOM_PDC = yes;
        QCOM_BAM_DMA = yes;
        QCOM_GPI_DMA = yes;
        QCOM_TSENS = yes;
        QCOM_SPMI_TEMP_ALARM = yes;
        QCOM_SPMI_ADC5 = yes;
        QCOM_WDT = yes;
        POWER_RESET_MSM = yes;
        POWER_RESET_QCOM_PON = yes;
        SYSCON_REBOOT_MODE = yes;
        NVMEM_QCOM_QFPROM = yes;
        QCOM_TZMEM_MODE_GENERIC = yes;
        RTC_DRV_PM8XXX = yes;

        # Keep USB gadget support available before loading modules.
        USB_DWC3 = yes;
        USB_XHCI_HCD = yes;
        USB_DWC3_QCOM = yes;
        USB_GADGET = yes;
        USB_CONFIGFS = yes;
        USB_CONFIGFS_SERIAL = yes;
        USB_CONFIGFS_ACM = yes;
        USB_CONFIGFS_ECM = yes;
        TYPEC = yes;
        TYPEC_TCPM = yes;
        TYPEC_QCOM_PMIC = yes;
        PHY_QCOM_QUSB2 = yes;
        PHY_QCOM_USB_SNPS_FEMTO_V2 = yes;

        # Wi-Fi remoteproc startup remains controlled by the host services.
        QRTR = yes;
        QRTR_SMD = yes;
        ATH10K = module;
        ATH10K_SNOC = module;
        REMOTEPROC = yes;
        QCOM_Q6V5_PAS = module;
        QCOM_SYSMON = yes;
        RPMSG_QCOM_GLINK_RPM = yes;
        RPMSG_QCOM_GLINK_SMEM = yes;
        RPMSG_QCOM_SMD = yes;
        QCOM_AOSS_QMP = yes;
        QCOM_RMTFS_MEM = yes;
        QCOM_PD_MAPPER = no;

        # Retain Capri's downstream audio hardware support.
        PINCTRL_LPASS_LPI = yes;
        PINCTRL_SM4250_LPASS_LPI = yes;
        QCOM_FASTRPC = yes;
        QCOM_APR = yes;
        SOUND = yes;
        SND = yes;
        SND_SOC = yes;
        SND_SOC_QCOM = yes;
        SND_SOC_CAPRI = yes;
        SND_SOC_AW882XX_CAPRI = yes;
      }
      // structuredExtraConfig;
    kernelPatches = [
      {
        # Full native Capri PMI632/SMB5/QGauge patch, including the Power DTB
        # and formerly separate NixOS kernel configuration dependencies.
        name = "capri-native-smb5";
        patch = ../patches/0001-kernel-capri-native-smb5.patch;
      }
    ]
    ++ (args.kernelPatches or [ ]);
    inherit randstructSeed;
    features = features // {
      efiBootStub = true;
    };
    target = "Image";
    buildDTBs = true;
  };
in
kernel.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ python3 ];

  # CONFIG_ARM64_MOTOROLA_CAPRI_BOOT embeds the handset DTB into the Image.
  # Build the Power variant first so capri-fdt.o can include the generated header.
  preBuild = (old.preBuild or "") + ''
    make "''${makeFlags[@]}" qcom/sm4250-motorola-capri-power.dtb
    ${python3}/bin/python3 scripts/capri/embed-dtb.py \
      "$buildRoot/arch/arm64/boot/dts/qcom/sm4250-motorola-capri-power.dtb" \
      "$buildRoot/include/generated/capri-dtb.h"
    test -s "$buildRoot/include/generated/capri-dtb.h"
  '';
})

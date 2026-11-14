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
    # Start from the tested Capri device defconfig, not all ARM64 platforms.
    # NixOS common options and hardware overrides are layered on top.
    defconfig = "motorola_capri_defconfig";
    # ARM64 host utilities (resolve_btfids) use glibc UAPI headers whose
    # __u128 type is absent from the kernel tools' older Linux UAPI shim.
    # Keep BTF/eBPF enabled; supply the missing host-only integer alias.
    extraMakeFlags = [
      "HOSTCFLAGS=-D__u128=__uint128_t"
    ];
    # Nixpkgs' generic common config pulls in drivers for unrelated SoCs.
    # Use explicit boot, systemd, filesystem and Capri settings instead.
    enableCommonConfig = false;
    # Do not auto-enable every optional hardware driver as a module.
    # Keep explicitly selected Capri modules and their Kconfig dependencies.
    autoModules = false;
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
        # Android provisions removable microSD cards with an MBR partition
        # table. Without this, mmcblk1 appears but mmcblk1p1 does not, so
        # initrd cannot resolve /dev/disk/by-label/NIXOS_CAPRI.
        MSDOS_PARTITION = yes;
        BLK_DEV_INITRD = yes;
        RD_GZIP = yes;
        RD_ZSTD = yes;
        VT = yes;
        VT_CONSOLE = yes;
        VT_HW_CONSOLE_BINDING = yes;
        FRAMEBUFFER_CONSOLE = yes;
        INPUT_EVDEV = yes;
        INPUT_UINPUT = yes;

        # NixOS requiredKernelConfig and Mobile NixOS core baseline.
        # These are userspace/systemd essentials, not extra hardware drivers.
        CRYPTO_HMAC = yes;
        CRYPTO_USER_API_HASH = yes;
        AUTOFS_FS = yes;
        ADVISE_SYSCALLS = yes;
        MEMBARRIER = yes;
        AIO = yes;
        IO_URING = yes;
        RSEQ = yes;
        # I/O accounting and memory pressure reporting for systemd/cgroups.
        BLK_CGROUP = yes;
        PSI = yes;

        # Mobile NixOS-inspired cgroup v2 resource controls.
        # Containers need CPU quotas and I/O throttling, not extra SoC drivers.
        CFS_BANDWIDTH = yes;
        BLK_DEV_THROTTLING = yes;
        BLK_CGROUP_IOLATENCY = yes;
        BLK_CGROUP_IOCOST = yes;
        # Prefer multi-generation page reclaim on RAM-constrained phones.
        LRU_GEN = yes;
        LRU_GEN_ENABLED = yes;
        # Optional userspace-program binary handlers (e.g. QEMU binfmt).
        BINFMT_MISC = module;

        # General-purpose Linux: isolation, security and observability.
        # Keep these subsystems while excluding unrelated SoC drivers.
        CGROUP_CPUACCT = yes;
        AUDIT = yes;
        AUDITSYSCALL = yes;
        SECURITY = yes;
        SECURITYFS = yes;
        # NixOS controls active LSMs via security.lsm; do not force AppArmor.
        SECURITY_LANDLOCK = yes;
        SECURITY_YAMA = yes;
        HARDENED_USERCOPY = yes;
        FORTIFY_SOURCE = yes;
        SLAB_FREELIST_HARDENED = yes;
        SLAB_FREELIST_RANDOM = yes;
        # ARM64/GCC has stack-protector support; verify generated Kconfig.
        STACKPROTECTOR = yes;
        STACKPROTECTOR_STRONG = yes;
        DEBUG_KERNEL = yes;
        DETECT_HUNG_TASK = yes;
        BPF_JIT = yes;
        PERF_EVENTS = yes;
        KPROBES = yes;
        # Useful to diagnose drivers without enabling the full debug suite.
        FTRACE = yes;

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

        # Normal Linux storage features as optional modules, not boot-critical.
        # Internal microSD/eMMC + EXT4 stay built in above.
        BLK_DEV_LOOP = module;
        MD = yes; # Parent menu for device mapper and LUKS; RAID remains disabled.
        BLK_DEV_DM = module;
        DM_CRYPT = module;
        DM_VERITY = module;
        FS_ENCRYPTION = yes;
        SCSI = yes;
        BLK_DEV_BSG = yes;
        BLK_DEV_SD = module;
        USB_STORAGE = module;
        USB_UAS = module;
        FAT_FS = module;
        VFAT_FS = module;
        EXFAT_FS = module;
        BTRFS_FS = module;
        F2FS_FS = module;
        SQUASHFS = module;
        SQUASHFS_ZSTD = yes;
        EROFS_FS = module;
        NLS_UTF8 = yes;
        NLS_CODEPAGE_437 = module;
        NLS_ISO8859_1 = module;
        # Qualcomm/display DMA allocations may require contiguous pages.
        CMA = yes;
        # User-space suspend inhibition for mobile-style power control.
        PM_WAKELOCKS = yes;
        DMA_CMA = yes;
        CMA_SIZE_MBYTES = freeform "32";
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
        QCOM_LLCC = yes;
        QCOM_OCMEM = yes;
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
        # Boot from the PMIC clock and persist NTP-corrected UTC back to it.
        RTC_HCTOSYS = yes;
        RTC_HCTOSYS_DEVICE = freeform "rtc0";
        RTC_SYSTOHC = yes;
        RTC_SYSTOHC_DEVICE = freeform "rtc0";

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

        # General-purpose software networking; unrelated NIC/SoC drivers stay off.
        # Keep the boot-time IP, TUN and netfilter core built in.
        NET_CORE = yes;
        INET = yes;
        IPV6 = yes;
        IP_ADVANCED_ROUTER = yes;
        IP_MULTIPLE_TABLES = yes;
        IP_ROUTE_MULTIPATH = yes;
        IP_MULTICAST = yes;
        IP_MROUTE = yes;
        IP_MROUTE_MULTIPLE_TABLES = yes;
        IP_PIMSM_V2 = yes;
        IPV6_MULTIPLE_TABLES = yes;
        IPV6_SUBTREES = yes;
        IPV6_ROUTER_PREF = yes;
        IPV6_ROUTE_INFO = yes;
        IPV6_MROUTE = yes;
        IPV6_MROUTE_MULTIPLE_TABLES = yes;
        IPV6_PIMSM_V2 = yes;
        IPV6_SEG6_LWTUNNEL = yes;
        IPV6_SEG6_HMAC = yes;
        SYN_COOKIES = yes;
        TCP_CONG_ADVANCED = yes;
        TCP_CONG_CUBIC = yes;
        TCP_CONG_BBR = module;
        TCP_CONG_DCTCP = module;
        TCP_MD5SIG = yes;
        TCP_AO = yes;
        INET_DIAG = module;
        INET_UDP_DIAG = module;
        INET_RAW_DIAG = module;
        INET_DIAG_DESTROY = yes;
        TUN = yes;
        MODULE_UNLOAD = yes;

        # Container interfaces, VLANs, overlays and routing domains.
        VETH = module;
        BRIDGE = module;
        VLAN_8021Q = module;
        BRIDGE_IGMP_SNOOPING = yes;
        BRIDGE_VLAN_FILTERING = yes;
        BRIDGE_NETFILTER = module;
        BONDING = module;
        DUMMY = module;
        MACVLAN = module;
        MACVTAP = module;
        IPVLAN = module;
        IPVTAP = module;
        VXLAN = module;
        GENEVE = module;
        BAREUDP = module;
        NET_L3_MASTER_DEV = yes;
        NET_VRF = module;
        NLMON = module;
        NETKIT = yes;
        OPENVSWITCH = module;
        OPENVSWITCH_GRE = module;
        OPENVSWITCH_VXLAN = module;
        OPENVSWITCH_GENEVE = module;

        # VPNs and IPv4/IPv6 tunnels.
        WIREGUARD = module;
        OVPN = module;
        MACSEC = module;
        NET_IPIP = module;
        NET_IPGRE_DEMUX = module;
        NET_IPGRE = module;
        NET_IPGRE_BROADCAST = yes;
        NET_FOU = module;
        NET_FOU_IP_TUNNELS = yes;
        IPV6_SIT = module;
        IPV6_SIT_6RD = yes;
        IPV6_TUNNEL = module;
        IPV6_GRE = module;
        XFRM_USER = module;
        XFRM_INTERFACE = module;
        XFRM_SUB_POLICY = yes;
        XFRM_STATISTICS = yes;
        INET_AH = module;
        INET_ESP = module;
        INET_IPCOMP = module;
        INET6_AH = module;
        INET6_ESP = module;
        INET6_IPCOMP = module;
        NET_IPVTI = module;
        IPV6_VTI = module;
        L2TP = module;
        L2TP_V3 = yes;
        L2TP_IP = module;
        L2TP_ETH = module;
        PPP = module;
        PPP_FILTER = yes;
        PPP_MULTILINK = yes;
        PPP_DEFLATE = module;
        PPP_BSDCOMP = module;
        PPP_MPPE = module;
        PPPOE = module;
        PPPOL2TP = module;
        PPP_ASYNC = module;
        PPP_SYNC_TTY = module;

        # Queueing, shaping, classification and BPF/tc actions.
        NET_SCHED = yes;
        NET_SCH_HTB = module;
        NET_SCH_HFSC = module;
        NET_SCH_PRIO = module;
        NET_SCH_SFQ = module;
        NET_SCH_TBF = module;
        NET_SCH_RED = module;
        NET_SCH_NETEM = module;
        NET_SCH_DRR = module;
        NET_SCH_MQPRIO = module;
        NET_SCH_CODEL = module;
        NET_SCH_FQ_CODEL = module;
        NET_SCH_CAKE = module;
        NET_SCH_FQ = module;
        NET_SCH_PIE = module;
        NET_SCH_FQ_PIE = module;
        NET_SCH_INGRESS = module;
        NET_CLS_BASIC = module;
        NET_CLS_ROUTE4 = module;
        NET_CLS_FW = module;
        NET_CLS_U32 = module;
        CLS_U32_PERF = yes;
        CLS_U32_MARK = yes;
        NET_CLS_FLOW = module;
        NET_CLS_CGROUP = module;
        NET_CLS_BPF = module;
        NET_CLS_FLOWER = module;
        NET_CLS_MATCHALL = module;
        NET_CLS_ACT = yes;
        NET_ACT_POLICE = module;
        NET_ACT_GACT = module;
        NET_ACT_MIRRED = module;
        NET_ACT_SAMPLE = module;
        NET_ACT_NAT = module;
        NET_ACT_PEDIT = module;
        NET_ACT_SKBEDIT = module;
        NET_ACT_CSUM = module;
        NET_ACT_VLAN = module;
        NET_ACT_BPF = module;
        NET_ACT_CONNMARK = module;
        NET_ACT_CTINFO = module;
        NET_ACT_SKBMOD = module;
        NET_ACT_TUNNEL_KEY = module;
        NET_ACT_CT = module;
        IFB = module;

        # Conntrack/NAT and userspace control, including Tailscale marks.
        NETFILTER = yes;
        NETFILTER_ADVANCED = yes;
        NETFILTER_INGRESS = yes;
        NETFILTER_EGRESS = yes;
        NF_CONNTRACK = yes;
        NF_CONNTRACK_MARK = yes;
        NF_CONNTRACK_ZONES = yes;
        NF_CONNTRACK_EVENTS = yes;
        NF_CONNTRACK_TIMEOUT = yes;
        NF_CONNTRACK_TIMESTAMP = yes;
        NF_CONNTRACK_LABELS = yes;
        NF_CT_PROTO_SCTP = yes;
        NF_CT_NETLINK = module;
        NF_CT_NETLINK_TIMEOUT = module;
        NETFILTER_NETLINK_QUEUE = module;
        NETFILTER_NETLINK_LOG = module;
        NETFILTER_NETLINK_ACCT = module;
        NETFILTER_NETLINK_GLUE_CT = yes;
        NF_CT_NETLINK_HELPER = module;
        NF_NAT = yes;
        NF_LOG_SYSLOG = module;
        NF_CONNTRACK_FTP = module;
        NF_CONNTRACK_SIP = module;
        NF_CONNTRACK_TFTP = module;
        NF_CONNTRACK_H323 = module;
        NF_CONNTRACK_SNMP = module;
        NF_CONNTRACK_NETBIOS_NS = module;
        NF_CONNTRACK_SANE = module;
        NF_NAT_FTP = module;
        NF_NAT_SIP = module;
        NF_NAT_TFTP = module;
        NF_NAT_H323 = module;
        NF_NAT_SNMP_BASIC = module;

        # Native nftables expressions for IPv4, IPv6, ARP and bridges.
        NF_TABLES = yes;
        NF_TABLES_INET = yes;
        NF_TABLES_ARP = yes;
        NF_TABLES_NETDEV = yes;
        NF_TABLES_BRIDGE = module;
        NFT_CT = module;
        NFT_NAT = module;
        NFT_MASQ = module;
        NFT_REDIR = module;
        NFT_REJECT = module;
        NFT_REJECT_IPV4 = module;
        NFT_REJECT_IPV6 = module;
        NFT_LOG = module;
        NFT_LIMIT = module;
        NFT_QUEUE = module;
        NFT_QUOTA = module;
        NFT_NUMGEN = module;
        NFT_HASH = module;
        NFT_CONNLIMIT = module;
        NFT_SOCKET = module;
        NFT_TPROXY = module;
        NFT_XFRM = module;
        NFT_SYNPROXY = module;
        NFT_TUNNEL = module;
        NFT_FIB_IPV4 = module;
        NFT_FIB_IPV6 = module;
        NFT_FIB_INET = module;
        NFT_DUP_IPV4 = module;
        NFT_DUP_IPV6 = module;
        NFT_DUP_NETDEV = module;
        NFT_FWD_NETDEV = module;
        NFT_FIB_NETDEV = module;
        NFT_REJECT_NETDEV = module;
        NFT_BRIDGE_META = module;
        NFT_BRIDGE_REJECT = module;
        NF_CONNTRACK_BRIDGE = module;
        NF_FLOW_TABLE = module;
        NF_FLOW_TABLE_INET = module;
        NFT_FLOW_OFFLOAD = module;

        # iptables-nft compatibility and optional legacy table backends.
        # Enabling kernel support does not select the userspace backend.
        NETFILTER_XTABLES = module;
        NETFILTER_XTABLES_LEGACY = yes;
        NFT_COMPAT = module;
        IP_NF_IPTABLES = module;
        IP6_NF_IPTABLES = module;
        IP_NF_IPTABLES_LEGACY = module;
        IP6_NF_IPTABLES_LEGACY = module;
        IP_NF_FILTER = module;
        IP6_NF_FILTER = module;
        IP_NF_MANGLE = module;
        IP6_NF_MANGLE = module;
        IP_NF_RAW = module;
        IP6_NF_RAW = module;
        IP_NF_NAT = module;
        IP6_NF_NAT = module;
        IP_NF_TARGET_REJECT = module;
        IP6_NF_TARGET_REJECT = module;
        IP6_NF_TARGET_NPT = module;
        IP_NF_MATCH_RPFILTER = module;
        IP6_NF_MATCH_RPFILTER = module;
        NETFILTER_XT_MARK = module;
        NETFILTER_XT_CONNMARK = module;
        NETFILTER_XT_NAT = module;
        NETFILTER_XT_TARGET_MARK = module;
        NETFILTER_XT_TARGET_CONNMARK = module;
        NETFILTER_XT_TARGET_CT = module;
        NETFILTER_XT_TARGET_MASQUERADE = module;
        NETFILTER_XT_TARGET_REDIRECT = module;
        NETFILTER_XT_TARGET_NETMAP = module;
        NETFILTER_XT_TARGET_LOG = module;
        NETFILTER_XT_TARGET_NFLOG = module;
        NETFILTER_XT_TARGET_NFQUEUE = module;
        NETFILTER_XT_TARGET_TCPMSS = module;
        NETFILTER_XT_TARGET_TPROXY = module;
        NETFILTER_XT_TARGET_TRACE = module;
        NETFILTER_XT_TARGET_CHECKSUM = module;
        NETFILTER_XT_TARGET_CLASSIFY = module;
        NETFILTER_XT_TARGET_DSCP = module;
        NETFILTER_XT_TARGET_HL = module;
        NETFILTER_XT_TARGET_TEE = module;
        NETFILTER_XT_MATCH_ADDRTYPE = module;
        NETFILTER_XT_MATCH_BPF = module;
        NETFILTER_XT_MATCH_CGROUP = module;
        NETFILTER_XT_MATCH_COMMENT = module;
        NETFILTER_XT_MATCH_CONNBYTES = module;
        NETFILTER_XT_MATCH_CONNLABEL = module;
        NETFILTER_XT_MATCH_CONNLIMIT = module;
        NETFILTER_XT_MATCH_CONNMARK = module;
        NETFILTER_XT_MATCH_CONNTRACK = module;
        NETFILTER_XT_MATCH_DSCP = module;
        NETFILTER_XT_MATCH_ECN = module;
        NETFILTER_XT_MATCH_HASHLIMIT = module;
        NETFILTER_XT_MATCH_HELPER = module;
        NETFILTER_XT_MATCH_HL = module;
        NETFILTER_XT_MATCH_IPRANGE = module;
        NETFILTER_XT_MATCH_LENGTH = module;
        NETFILTER_XT_MATCH_LIMIT = module;
        NETFILTER_XT_MATCH_MAC = module;
        NETFILTER_XT_MATCH_MARK = module;
        NETFILTER_XT_MATCH_MULTIPORT = module;
        NETFILTER_XT_MATCH_OWNER = module;
        NETFILTER_XT_MATCH_PHYSDEV = module;
        NETFILTER_XT_MATCH_PKTTYPE = module;
        NETFILTER_XT_MATCH_POLICY = module;
        NETFILTER_XT_MATCH_QUOTA = module;
        NETFILTER_XT_MATCH_RECENT = module;
        NETFILTER_XT_MATCH_SCTP = module;
        NETFILTER_XT_MATCH_SOCKET = module;
        NETFILTER_XT_MATCH_STATE = module;
        NETFILTER_XT_MATCH_STATISTIC = module;
        NETFILTER_XT_MATCH_STRING = module;
        NETFILTER_XT_MATCH_TCPMSS = module;
        NETFILTER_XT_MATCH_TIME = module;
        NETFILTER_XT_MATCH_U32 = module;

        # IP sets for firewall address/port collections.
        IP_SET = module;
        IP_SET_BITMAP_IP = module;
        IP_SET_BITMAP_IPMAC = module;
        IP_SET_BITMAP_PORT = module;
        IP_SET_HASH_IP = module;
        IP_SET_HASH_IPMARK = module;
        IP_SET_HASH_IPPORT = module;
        IP_SET_HASH_IPPORTIP = module;
        IP_SET_HASH_IPPORTNET = module;
        IP_SET_HASH_IPMAC = module;
        IP_SET_HASH_MAC = module;
        IP_SET_HASH_NET = module;
        IP_SET_HASH_NETNET = module;
        IP_SET_HASH_NETPORT = module;
        IP_SET_HASH_NETPORTNET = module;
        IP_SET_HASH_NETIFACE = module;
        IP_SET_LIST_SET = module;
        NETFILTER_XT_SET = module;

        # IPVS load balancing for service/container networking.
        IP_VS = module;
        IP_VS_IPV6 = yes;
        IP_VS_PROTO_TCP = yes;
        IP_VS_PROTO_UDP = yes;
        IP_VS_PROTO_ESP = yes;
        IP_VS_PROTO_AH = yes;
        IP_VS_PROTO_SCTP = yes;
        IP_VS_RR = module;
        IP_VS_WRR = module;
        IP_VS_LC = module;
        IP_VS_WLC = module;
        IP_VS_FO = module;
        IP_VS_OVF = module;
        IP_VS_LBLC = module;
        IP_VS_LBLCR = module;
        IP_VS_DH = module;
        IP_VS_SH = module;
        IP_VS_MH = module;
        IP_VS_SED = module;
        IP_VS_NQ = module;
        IP_VS_TWOS = module;
        NETFILTER_XT_MATCH_IPVS = module;

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
      {
        name = "capri-microsd-sdhc2";
        patch = ../patches/0002-kernel-capri-microsd-sdhc2.patch;
      }
      {
        # U-Boot extlinux supplies our native Power FDT, not Motorola's
        # qcom,bengal-capri firmware FDT; keep its live memory/initrd fixups.
        name = "capri-native-uboot-fdt";
        patch = ../patches/0003-kernel-capri-native-uboot-fdt.patch;
      }
      {
        name = "capri-rtc-set-time";
        patch = ../patches/0004-kernel-capri-rtc-set-time.patch;
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

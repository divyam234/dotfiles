# Capri native NixOS packages

These packages build from pinned sources, not prebuilt kernel/U-Boot binaries.
The U-Boot package applies its board patches; the 7.4 kernel needs no local
board patch stack.

## U-Boot: `0001-uboot-motorola-capri-upstream-v2026.07.patch`

- Base: official [U-Boot](https://github.com/u-boot/u-boot), tag `v2026.07`, commit `ece349ade2973e220f524ce59e59711cc919263f` (verified locally with `git rev-parse v2026.07^{commit}`).
- Patch exports commits `v2026.07..592c95f5ce654b153e1e95c416887ccee2063510` from the existing `capri-upstream-uboot` tree.
- Contains Qualcomm ABL handoff support, protected framebuffer handling, Capri configuration/DT and boot menu, EFI fixes, and supporting documentation.
- Compiling it will still require the Capri build configuration (`qcom_defconfig` plus the added `motorola-capri.config`) and packaging `u-boot.bin` into the Motorola Android header-v3 `boot.img` with `mkbootimg`. This patch does not by itself create the final boot.img.
- Sanity check on the current patched tree: `git apply --reverse --check <patch>`; on a clean checkout of the base tag: `git apply --check <patch>`.

The Nix package overlays `uboot/default.env` with an internal-eMMC-only
environment. At startup, a diagnostics/boot menu appears with a six-second
countdown. Any menu key stops the countdown; Volume Up/Down navigates and
Power selects. If untouched, the first entry boots NixOS generations.
Volume Up is a separate GPIO button (PM6125 GPIO5, active-low);
`0003-uboot-capri-volume-up.patch` exposes it with KEY_VOLUMEUP and the
package enables BUTTON_GPIO. PON handles Volume Down and Power. U-Boot's
button keyboard maps these to Up, Down and Enter respectively.
The initial legacy-GPIO version did not respond to Volume Up. Routing PM6125
to U-Boot's bias-aware SPMI GPIO driver and requesting GPIO5's pull-up fixed
it; the user confirmed upward navigation. The bootloader reboot entry also
worked, with fastboot serial `ZF65268ZPB` detected afterward.
`bootdelay=-2` enters this menu immediately rather than adding a separate
pre-menu autoboot delay. The explicit `bootmenu 6` controls the countdown.
Diagnostic options do not require an automatic eMMC scan before the menu.

After selecting the first entry, U-Boot's Standard Boot reads userdata's
`/boot/extlinux/extlinux.conf` using `bootflow scan -lb mmc0:0x4d`;
`0x4d` is partition 77. A failed boot returns to the diagnostic menu, with
no microSD fallback. The recovery menu has no timeout after the selected
command returns. NixOS's extlinux generation picker retains its separately
configured timeout; the six seconds above are the initial U-Boot menu only.
The menu retains a manual EFI boot option.
It also offers **Reboot bootloader**, which sets the same PON GEN2 bootloader
reason as Linux before resetting, without enabling U-Boot's fastboot server.

The Capri-specific extlinux generation picker uses the same Up/Down/Enter
decoder as the main menu, plus **Back to main menu**. It retains extlinux's
default/override selection and countdown. Back/cancel does not attempt
fallback generations; the calling bootcmd returns to the untimed main menu.
The extlinux parser and kernel/DTB/initramfs loader are unchanged.
Other boards retain their original PXE picker.

Host-only selection tests:

```
cc -std=c11 -O2 -Wall -Wextra -Werror \
  packages/capri/tests/generation-menu-test.c -o /tmp/opencode/generation-menu-test
/tmp/opencode/generation-menu-test
```

The user confirmed physical generation-menu navigation and Back work on the
handset, including repeated entry/return. Tested RAM-only image:
`/nix/store/8jck303sd7rkba2fb6955hmri60bphky-capri-uboot-android-v3-boot-image/boot-uboot-capri-v3.img`,
SHA-256 `51a0dc2c5f8adff152791481fe02075b10571f6382753a1a0a2c58d752e10f77`.
This verifies the picker and recovery flow, not a newly built full NixOS
system or an installed 7.4 NixOS generation. No partitions were flashed.
The Nix build requires `BOOTSTD`, `BOOTMETH_EXTLINUX` and `CMD_BOOTFLOW`,
and disables storage writes, GPT changes, flashing, capsules and persistent
environment storage. Load addresses come from Snapdragon's runtime memory
allocator, not fixed addresses. NixOS mounts `/dev/disk/by-label/NIXOS_EMMC`.

The Android header-v3 U-Boot image's empty ramdisk is only a packaging
placeholder. NixOS's real initramfs is loaded from the ext4 root filesystem.

## Kernel: native Capri Linux 7.4-rc3

- **Pinned source:** [divyam234/capri-linux](https://github.com/divyam234/capri-linux), revision `a8c2f8e868bcf1a3e9ad9d75d0d9aa2f72e9e1ee` (Linux 7.4-rc3).
- **No local board patch stack:** Capri board support, NixOS defconfig settings and the GPIO33 assistant button are in the pinned source. The old 7.2 patches are no longer applied.
- **Native drivers:** adds Qualcomm QGauge, the adapted SMB2/SMB5 PMI632 charger and battery ADC thermal zone; removes the former `capri-pmi632-battery.c` driver and its proprietary charging policy. Provides the Moto G10 Power XT2127-4 DTS and PMIC metadata.
- **Charging policy:** uses the configured 4.450 V float voltage, native PMIC JEITA and watchdog protection, a board-specific current/termination policy, and Motorola-style hardware `BAT_OV` detection with its 40 mV reporting tolerance. The temporary software cutoff at the float target has been removed.
- **NixOS options:** `structuredExtraConfig` sets every required build flag, including `QCOM_LLCC`, `QCOM_OCMEM`, `QCOM_APR`, `BACKLIGHT_CLASS_DEVICE`, `CHARGER_QCOM_SMB2`, `BATTERY_QCOM_QG`, `GENERIC_ADC_THERMAL` and `NVMEM_SPMI_SDAM`. No defconfig patch is needed.
- **Build:** native ARM64 `Image` and a separate Power DTB supplied by U-Boot. No embedded DTB, custom ABL handoff or embed-dtb build hook. Touch is built in.
- **Hardware verification:** the 7.4 kernel booted RAMUI through U-Boot with working display, touch, USB recovery and Bluetooth LE scan. GPIO33 screen off/on was user-confirmed with the console guard. This does not establish a booted full NixOS system, Wi-Fi operation, or full-cycle charging validation.

The historical [PMI632 charging validation](CHARGING-VALIDATION.md) and
`CAPRI-NATIVE-SMB5-STATUS.md` in the **kernel development repository** remain
separate documentation; neither is bundled into the Nix source patch.
The older charging and patch notes below are historical; they are not
instructions to apply the removed 7.2 patch stack to 7.4.

### Assistant-button display toggle

`hosts/capri/screen-button.nix` starts the packaged `capri-screen-button`
alongside Buffyboard on the real root filesystem. GPIO33 emits
`KEY_ASSISTANT`; the first press guards tty1 with `KD_GRAPHICS` and requests
fbdev/DRM powerdown, the second unblanks and restores the text console.
The guard prevents the observed 2–3 second automatic re-illumination.
Held-key repeat is ignored. Linux, USB and touch remain running; this is
not suspend, a touch lock, or proof that all panel bias rails power off.

Normal termination restores the display. `ExecStopPost` also requests
recovery after a crash. For manual recovery over SSH:

```
sudo systemctl stop capri-screen-button
sudo capri-screen-button on
```

This policy requires active text-mode tty1, not a graphical compositor.
The package tests key filtering, VT guarding and error recovery without
hardware access. Final NixOS/Buffyboard integration still requires its own
hardware test; no activation or flashing is performed by these changes.

### Experimental awake-time battery percentage reporting

Historical 7.2 implementation: `0004-kernel-capri-qg-charge-reporting.patch`
and `kernel/qg-soc.h` were supplied by the Nix package. They are no longer
injected into the pinned 7.4 source. This was a reporting-only estimate, **not**
Qualcomm's complete Android fuel-gauge algorithm or hardware coulomb counting.
Charger limits, thermal protections, termination policy and SDAM are unchanged.

The existing driver seeds capacity from power-on OCV and otherwise only
updates it when the hardware supplies a good OCV. On an always-awake server,
capacity can stay at the boot estimate for hours while charging.

The experimental estimator:

- Seeds from the existing OCV percentage and SDAM full capacity, falling back
  to the battery's design capacity when learned capacity is unavailable.
- Integrates signed burst-current samples every five seconds while awake,
  retaining fractional charge. It does not use the S2 current average, which
  remained positive immediately after unplugging the charger in live testing.
- Drops the integration baseline after failed reads, charge/discharge
  transitions, suspend and sampling gaps over 30 seconds.
- Re-anchors on a new hardware-qualified OCV or charger-reported `Full`, and
  clamps reported capacity to 0–100. Battery removal invalidates the estimate.
- Does not persist SOC or extrapolate through suspended time. The initial
  estimate may be wrong if power-on OCV is stale; an increasing percentage
  alone does not establish absolute accuracy. Full-cycle device validation
  is still required.

Reference: LineageOS's
[`qpnp-qg.c`](https://github.com/LineageOS/android_kernel_motorola_sm6225/blob/1da2d0861244d324cfff0fcb31dec374dd94436b/drivers/power/supply/qcom/qpnp-qg.c)
accepts userspace SOC values in `process_udata_work()`;
[`qg-soc.c`](https://github.com/LineageOS/android_kernel_motorola_sm6225/blob/1da2d0861244d324cfff0fcb31dec374dd94436b/drivers/power/supply/qcom/qg-soc.c)
smooths the reported SOC rather than providing a standalone estimator.
The downstream subtype-dependent current conversion agrees with the
conversion already present in Capri's native driver. Unplug/replug testing
confirmed negative discharge and positive charge readings, but did not
independently calibrate current magnitude.

Run the focused arithmetic/boundary tests without building a kernel:

```sh
nix build --no-link .#checks.aarch64-linux.capri-qg-soc
```

Before deploying, compile the driver in the actual ARM64 kernel, then validate
percentage movement, unplug/replug transitions, full-charge anchoring and
suspend/resume on the phone. A kernel change needs a reboot; `just test` does
not replace the running kernel. Retain a known-working boot entry.

## Important

- **Do not apply patches twice**; the local `capri-7.2` source tree already includes the consolidated kernel changes. Nix applies the single patch to the pinned older revision.
- The U-Boot source is the *official U-Boot tree* with a Capri downstream patchset; the kernel source is the *Capri downstream Linux tree*, not vanilla Linux from Torvalds. Rebasing Capri kernel support directly onto a vanilla tag would be a much larger, separate patch series.
- Firmware and device-specific modem NV files are **not** in these patches. Do not add modemst/fsg/fsc or other personal NV snapshots to the Nix store or repository.
- Patch application checks are necessary but do not by themselves prove that Nix successfully compiles both sources or that a NixOS root filesystem boots on the phone.

## Wi-Fi-only Qualcomm startup in native Capri NixOS

The native `capri` NixOS host imports `hosts/capri/modem-nv.nix` directly.
There is no Android-hosted container layer. The systemd dependency chain is:

1. `capri-qrtr-ns`: QRTR name service.
2. `capri-modem-nv-readonly`: ensure the real `modemst1`,
   `modemst2`, `fsg_b`, `fsc` partitions exist, set each block device
   read-only at runtime, and create a temporary `fsg -> fsg_b` alias.
3. `capri-rmtfs`: `rmtfs -P -r -o /run/capri-rmtfs/by-partlabel`,
   which reads those partition nodes directly and keeps requested writes
   in volatile RAM.
4. `capri-pd-mapper` and `capri-tqftpserv`: QRTR services built from
   source; the latter carries the exact proven RAMUI firmware lookup fix.
   Both use NixOS's `/run/current-system/firmware/` instead of Android's
   `/lib/firmware/` directory.
5. `capri-modem-start`: waits for services 14, 64 and 4096 to publish,
   then starts `remoteproc0` (Qualcomm modem firmware processor).
6. `capri-wifi-driver`: loads `ath10k_snoc` after modem startup.
   NetworkManager handles Wi-Fi association and DHCP.

The verified Motorola firmware is packaged from
`packages/capri/firmware/capri-motorola-verified.tar.xz`. It is
uncompressed in the installed NixOS firmware output for userspace
Qualcomm daemons. `ModemManager` and mobile data remain disabled.

**Never mount, format, erase, read, or write Android `persist`.**
Do not add modem NV captures to Git or the Nix store. The preparation
service never mounts or rewrites the four existing modem partitions; the
`blockdev --setro` setting is in-memory and does not modify on-disk
partition attributes.

**Validation:** Nix package builds, generated script builds, formatting,
and isolated native NixOS option evaluation previously passed. Real-device
testing of direct NV block access, automatic remoteproc startup, WPA
association and DHCP remains outstanding. The `capri` flake configuration
is intended for native NixOS; it is not yet a tested bootable phone image.

## Native boot evaluation status

The Nix kernel derivation uses `buildLinux` with the pinned source's
`motorola_capri_defconfig`, not the generic all-platform ARM64 defconfig.
`enableCommonConfig = false` and `autoModules = false` avoid enabling
unrelated SoC drivers or every optional module. Required NixOS boot, systemd,
networking and Capri hardware options are selected explicitly in
`kernel/default.nix` and validated strictly with `ignoreConfigErrors = false`.

The previous generic config had 4,207 built-in Kconfig symbols and 7,566
module symbols; the overly minimal Capri config had 1,010 built-ins and 22
modules. The curated general-purpose Capri configuration, incorporating
Mobile NixOS's relevant kernel recommendations, has **1,150 built-ins and
71 modules**. These are enabled Kconfig symbols, not source file counts.
Strict config-only validation passes, but the full kernel and device boot
remain untested.

Boot-critical display, eMMC/ext4, USB and Qualcomm dependencies stay built in;
the touchscreen, ATH10K SNOC and modem remoteproc drivers remain modules.
The in-kernel PD mapper stays disabled because Capri starts a userspace PD
mapper service.

Overrides enable EFI/stub/GPT support, gzip/zstd initramfs decompression and the
VT/framebuffer/input console path. The Power DTB patch and header-generation
step remain in place. The old generated `kernel/config` snapshot has been removed;
the generated configuration lives in the Nix store, not the repository.

Generate and validate only the configuration, without compiling the kernel:

```sh
nix build --no-link --print-out-paths \
  .#nixosConfigurations.capri.config.boot.kernelPackages.kernel.configfile
```

Configuration-only generation passed with `enableCommonConfig = false`,
`autoModules = false` and `ignoreConfigErrors = false`. The host's 24 entries in
`system.requiredKernelConfig` were checked against the earlier optimized
config and all passed. The curated config retains those mandatory settings
and enables additional normal Linux functionality:

- **Security/observability:** Landlock and Yama are enabled, and NixOS
  manages active LSMs through `security.lsm`. AppArmor is not requested in
  the Capri kernel configuration; enabling AppArmor later will require
  explicitly compiling and activating it. Auditing, hardened user copies,
  fortification, BPF JIT, perf, kprobes and ftrace remain enabled.
- **Storage:** modular loop and device-mapper targets, dm-crypt, dm-verity,
  SCSI USB mass storage/UAS, FAT/exFAT, Btrfs, F2FS, SquashFS and EROFS;
  `EXT4_FS` and the Qualcomm MMC controller remain built in.
- **Networking/containers:** IPv4/IPv6 policy, multipath and multicast routing;
  VLAN-aware bridges, bonding, veth, macvlan/ipvlan, VRF, VXLAN, Geneve and
  Open vSwitch; WireGuard, OpenVPN data-channel offload, IPsec, GRE/IP tunnels
  and PPP/L2TP. Optional protocols and virtual interfaces are modules; the
  boot-time IP, TUN, conntrack and nftables core stay built in.
- **Firewall:** native nftables IPv4/IPv6, ARP, bridge and netdev families;
  conntrack marks, zones, events and Netlink control; NAT, transparent proxying,
  logging, queueing, flow tables, IP sets and IPVS load balancing. Xtables
  includes `conntrack`, `MARK`, `CONNMARK`, `multiport`, `REJECT`, `MASQUERADE`,
  `pkttype`, and other software matches/targets for NixOS, Fail2ban and
  Tailscale. Both iptables-nft compatibility and optional legacy iptables
  tables are configured; this does not change the userspace firewall backend.
- **Traffic control:** HTB/HFSC, CAKE, FQ/FQ-CoDel, PIE, netem, IFB,
  classifiers and BPF/tc actions for shaping, filtering, redirecting and
  connection tracking. Namespaces, cgroups, block I/O accounting and PSI remain
  enabled.
- **Mobile hardware:** `CMA=y`, `DMA_CMA=y`, 32 MiB CMA default, alongside
  built-in Capri charging, display, SDHC2 and USB gadget drivers.
- **Additional Mobile NixOS-inspired support:** `CFS_BANDWIDTH` for cgroup CPU
  quotas; `BLK_DEV_THROTTLING`, `BLK_CGROUP_IOLATENCY` and
  `BLK_CGROUP_IOCOST` for I/O control; `LRU_GEN` and `LRU_GEN_ENABLED` for
  memory reclaim; slab freelist hardening/randomization and strong stack
  protectors; `DETECT_HUNG_TASK`; optional `BINFMT_MISC=m` and
  `SQUASHFS_ZSTD=y`; user-space `PM_WAKELOCKS=y`.

Motorola's `motorola_capri_defconfig` remains the hardware baseline: unrelated
ARM64 SoCs are still disabled. New storage/network device drivers are mostly
modules. This adds generic Linux capabilities without restoring Nixpkgs'
all-hardware driver expansion. A Kconfig-only test cannot prove that every
module compiles, loads, or works on physical hardware; the next full build and
boot tests must check that separately.

`RANDOMIZE_BASE` remains disabled until the native DT/U-Boot handoff is
verified; `RD_XZ` remains disabled since our initrd is compressed with Zstd.
The extra Android Binder and Mobile NixOS USB FunctionFS/RNDIS/NCM gadget
functions are not required by the current headless boot and remain outside
this networking expansion.

The expanded networking configuration above has not been evaluated, built,
or boot-tested. The running phone kernel is unchanged; its missing conntrack
match and MARK support are not fixed until a newly built kernel is installed
and verified.

## RTC time persistence

The PM6125 RTC remains readable through `rtc0`, with `RTC_HCTOSYS=y`.
Direct time writes are not enabled: the handset's SPMI ownership policy
denies writes to RTC control register `sid=0, addr=0x6046`. Enabling
`allow-set-time` does not grant that permission.

`RTC_SYSTOHC` is disabled so NTP synchronization does not repeatedly attempt
the blocked writes. NTP still corrects the system clock after networking
is available. The hardware RTC was observed reporting 1971; accurate time
across reboots requires a supported persistent offset mechanism, which has
not been verified on Capri. Do not seed this RTC with `hwclock --systohc`.

## Native storage and boot layout

Capri uses NixOS's built-in `generic-extlinux-compatible` loader, not
systemd-boot. U-Boot loads the kernel, NixOS initramfs and Power DTB from
`/boot` on the same ext4 filesystem as `/`. There is no separate EFI
filesystem and no need to resize or repurpose Android `super`.

The NixOS root filesystem lives on internal eMMC userdata,
`/dev/block/mmcblk0p77` in Android recovery, with verified capacity
50,179,587,584 bytes (98007007 sectors). NixOS mounts
`/dev/disk/by-label/NIXOS_EMMC` as `/`; the generated extlinux files live
in the same ext4 filesystem.

U-Boot keeps `boot_targets=mmc0` and explicitly selects userdata with
`bootflow scan -lb mmc0:0x4d`. The pinned upstream Standard Boot code limits
automatic scans to low partition numbers; the
`0002-uboot-bootflow-explicit-partition.patch` exempts explicit partition
requests from that limit, initializes their filesystem, and permits an
explicit target with a custom non-global boot-method order. Automatic scans
remain bounded. This avoids changing Android GPT boot flags or probing
calibration filesystems.
A read-only discovery command is `bootflow scan -ale mmc0:0x4d`.

The board DT maps `mmc0` to internal `sdhc_1`. Removable `sdhc_2` is disabled
in U-Boot and has no `mmc1` alias. Failed internal boot returns to the
diagnostic menu instead of starting an older system from the card.

Linux retains microSD support through `0002-kernel-capri-microsd-sdhc2.patch`
for use as ordinary storage; this does not enable it in U-Boot.

**Important:** Writing the rootfs image destroys Android userdata. Verify
the partition identity, capacity and unmounted state before writing only
that partition. Never write the whole `/dev/block/mmcblk0` disk.
Leave `super`, Qualcomm firmware and modem NV/calibration partitions,
including `persist`, `prodpersist`, `modemst1`, `modemst2`, `fsg_b` and `fsc`,
untouched. Test the U-Boot image through RAM-only `fastboot boot`; do not
flash Motorola boot slots or repartition Android as part of that test.

**Verification:** Rootfs installation can be checked by hashing exactly the
uncompressed image length from userdata before mounting or booting it.
The boot image is built separately; successful rootfs readback does not
prove that the running U-Boot selected internal eMMC.

USB ECM plus SSH is configured for the **normal** native NixOS system.
Early-initrd USB recovery and early-initrd Buffyboard remain unimplemented;
the RAMUI telnet service is not installed in NixOS.

## Compressed RAM swap

Capri enables zram swap with Zstd compression and a logical capacity of 50% of
RAM (about 1.8 GiB on the phone). Physical RAM is consumed as compressed pages
are stored, not reserved upfront. No disk swapfile is configured.
The running kernel has built-in zram and Zstd support; this configuration
requires system activation and has not been runtime-verified.

## Iets evaluator stack

The local Iets package supports `IETS_MAIN_STACK_MB` (16–4096 MiB), defaulting
to the upstream 4096 MiB when unset. It reads the value once per process and
uses it for both the evaluator thread and demand fiber, including reservation
accounting. Invalid values exit with a diagnostic.

Capri sets `IETS_MAIN_STACK_MB=2048` in login-shell and system-service
environments, including Home Manager. Other hosts retain the upstream default.
This reduces virtual stack reservation, not a fixed amount of RAM usage.
Deeply recursive evaluations have less stack headroom. The change has not been
built or runtime-verified; resolving the Home Manager failure remains unproven.

## USB ECM networking and existing SSH authentication

`hosts/capri/usb-ecm.nix` creates the configfs ECM USB network function after
normal NixOS boots. The phone uses `172.16.42.1/24` on `usb0`; NetworkManager
leaves that interface unmanaged while handling Wi-Fi independently.

The service reuses the existing ECM function across restarts without rewriting
its `ifname`: configfs rejects that write with `EBUSY` once the function is
linked, even after unbinding the gadget.

There is one OpenSSH service on port `2222`, with password authentication
disabled and existing `bhunter` authorized public keys. Both Wi-Fi and USB
use the same SSH user, authorized keys and security policy. There is no
`capriusb` account, no separate USB SSH daemon and no unauthenticated access.
The existing server policy denies direct root SSH logins.

On the Linux laptop, find the gadget's Ethernet interface and assign it
`172.16.42.2/24`, replacing `<usb-iface>` with its actual interface name:

```sh
ip -br link
sudo ip address add 172.16.42.2/24 dev <usb-iface>
sudo ip link set dev <usb-iface> up
ssh -p 2222 bhunter@172.16.42.1
```

Check `systemctl status capri-usb-ecm` and
`journalctl -b -u capri-usb-ecm` on the phone. The USB gadget requires a
normal userspace boot and remains unverified on real native NixOS hardware;
there is no early-initrd SSH service.

The SOPS age private identity is shared by NixOS and Home Manager. The key
must be installed on the real root filesystem (never in Git or the Nix store)
with these **exact EXT4 ownership and permissions**:

```text
/var/lib/sops-nix/          0:100  0750  (root:users)
/var/lib/sops-nix/key.txt   0:100  0640  (root:users)
```

Root can decrypt NixOS secrets; `bhunter` (group `users`) can read the same age
key for Home Manager. **Never replace it with `0:0 0600`** when preparing Capri
images. SSH still accepts only authorized public keys, not private keys.

## Ext4 internal eMMC rootfs image

`packages.aarch64-linux.capri-rootfs-image` produces a Zstandard-compressed,
unencrypted ext4 filesystem image using Nixpkgs' `make-ext4-fs.nix` with
`compressImage = true`. It contains the real Capri
system closure, its Nix registration manifest and the standard extlinux
kernel/initramfs/Power-DTB boot files. Only the selected initial generation is
included; build-host profiles are not imported.

The Capri host uses the full shared `base`, `server`, and
`home-manager-policy` aspects plus `teldrive-native`. The image includes
the server development tools and integrated Home Manager configuration,
alongside the current native hardware, charging, Wi-Fi, Buffyboard and USB
ECM support. SSH remains public-key-only on port 2222; console login uses
the normal SOPS-managed user password without autologin. The firewall uses
the default iptables backend, with `xt_pkttype` enabled in the kernel configuration.

Teldrive listens on `0.0.0.0:8090` and runs as root, matching the previous
full Capri profile. Its runtime secrets require the existing SOPS age key.
The image size depends on the full system closure and must be measured
after building.

Compression reduces storage and transfer size, not the installed filesystem
size. The partition-capacity guard measures the uncompressed image.

The output is a single filesystem, **not a whole-disk image**. It contains
no GPT or U-Boot boot image. The builder limits the image to the verified
98007007-sector internal userdata partition, and labels the filesystem
`NIXOS_EMMC` for the root mount. A first-boot service loads the
`/nix-path-registration` manifest and creates the initial NixOS system
profile. Filesystem auto-resizing only grows ext4 within its partition;
`boot.growPartition = false` forbids automatic partition-table growth.

Evaluate without compiling the Capri kernel:

```sh
nix eval --raw .#packages.aarch64-linux.capri-rootfs-image.drvPath
```

After kernel compilation is authorized, build the real image with:

```sh
nix build --out-link result-capri-rootfs .#capri-rootfs-image
```

The result link points to the compressed `.ext4.zst` filesystem image.
Decompress it before mounting it or provisioning the age key:

```sh
zstd -d result-capri-rootfs -o capri-rootfs.ext4
```

Building requires the Capri kernel but not U-Boot. Writing the image requires
the verified, unmounted internal userdata partition and explicit permission
to discard its existing data. Do not write the whole-disk device or the
removable microSD partition.

The builder deliberately does **not** embed runtime age keys, decrypted
secrets or modem NV snapshots. After building the EXT4 image, provision the
existing SOPS age key on its mounted real root filesystem, then verify both
ownership and permissions **before flashing**:

```sh
sudo install -d -o 0 -g 100 -m 0750 /mnt/capri-new/var/lib/sops-nix
sudo install -o 0 -g 100 -m 0640 \
  /mnt/capri-old/var/lib/sops-nix/key.txt \
  /mnt/capri-new/var/lib/sops-nix/key.txt
sudo stat -c '%u:%g %a %n' \
  /mnt/capri-new/var/lib/sops-nix \
  /mnt/capri-new/var/lib/sops-nix/key.txt
```

Expected: `0:100 750` for the directory and `0:100 640` for the key.
Do not bake this private key into a Nix derivation or store path.

**Validation:** Compression uses the existing Zstandard support in the pinned
Nixpkgs filesystem builder. The compression change has not been built or
checked; builds and checks require explicit authorization.

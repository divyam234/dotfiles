# Capri source patchset for native NixOS

These are **source patches**, not prebuilt kernel/U-Boot binaries. Pin and fetch the source revisions below in Nix; apply each patch using `patches = [ ... ]` (or an equivalent patch phase) before compilation.

## U-Boot: `0001-uboot-motorola-capri-upstream-v2026.07.patch`

- Base: official [U-Boot](https://github.com/u-boot/u-boot), tag `v2026.07`, commit `ece349ade2973e220f524ce59e59711cc919263f` (verified locally with `git rev-parse v2026.07^{commit}`).
- Patch exports commits `v2026.07..592c95f5ce654b153e1e95c416887ccee2063510` from the existing `capri-upstream-uboot` tree.
- Contains Qualcomm ABL handoff support, protected framebuffer handling, Capri configuration/DT and boot menu, EFI fixes, and supporting documentation.
- Compiling it will still require the Capri build configuration (`qcom_defconfig` plus the added `motorola-capri.config`) and packaging `u-boot.bin` into the Motorola Android header-v3 `boot.img` with `mkbootimg`. This patch does not by itself create the final boot.img.
- Sanity check on the current patched tree: `git apply --reverse --check <patch>`; on a clean checkout of the base tag: `git apply --check <patch>`.

The Nix package overlays `uboot/default.env` with the extlinux-first environment
from `capri-upstream-uboot` commit `c3af53f5`. U-Boot's Standard Boot scans
readable partitions for `extlinux/extlinux.conf` or `boot/extlinux/extlinux.conf`
using `bootflow scan -lb`; a failed scan falls back to the diagnostic menu.
The menu retains a manual EFI boot option. The Nix build requires
`BOOTSTD`, `BOOTMETH_EXTLINUX` and `CMD_BOOTFLOW`, and disables eMMC,
filesystem, GPT, flashing, capsule and persistent-environment write paths.
Load addresses come from Snapdragon's runtime memory allocator, not fixed addresses.
This replaces the former partition-77-specific `sysboot`/PARTUUID guard;
NixOS still mounts its root filesystem by the verified userdata PARTUUID.

The Android header-v3 U-Boot image's empty ramdisk is only a packaging
placeholder. NixOS's real initramfs is loaded from the ext4 root filesystem.

## Kernel: one consolidated native Capri SMB5/QGauge patch

- **Pinned source:** [michaelmcallister/linux-motorola-capri](https://github.com/michaelmcallister/linux-motorola-capri), revision `232c314e8909dd77395b2c553e7dda2232e4a4cc` (Linux 7.2.9).
- **Single kernel patch:** `0001-kernel-capri-native-smb5.patch`, containing the source, device-tree and binding changes from the pinned revision to local `capri-7.2` commit `33e75361c`. Both `defconfig` changes and all `.md` documentation are intentionally excluded. The previous Power charging patch and separate config patch have been removed.
- **Native drivers:** adds Qualcomm QGauge, the adapted SMB2/SMB5 PMI632 charger and battery ADC thermal zone; removes the former `capri-pmi632-battery.c` driver and its proprietary charging policy. Provides the Moto G10 Power XT2127-4 DTS and PMIC metadata.
- **Charging policy:** uses the configured 4.450 V float voltage, native PMIC JEITA and watchdog protection, a board-specific current/termination policy, and Motorola-style hardware `BAT_OV` detection with its 40 mV reporting tolerance. The temporary software cutoff at the float target has been removed.
- **NixOS options:** `structuredExtraConfig` sets every required build flag, including `QCOM_LLCC`, `QCOM_OCMEM`, `QCOM_APR`, `BACKLIGHT_CLASS_DEVICE`, `CHARGER_QCOM_SMB2`, `BATTERY_QCOM_QG`, `GENERIC_ADC_THERMAL` and `NVMEM_SPMI_SDAM`. No defconfig patch is needed.
- **Build:** `kernel/default.nix` builds the Power DTB and embeds it in the `Image` before linking. The local ARM64 kernel compiled successfully with Clang.
- **Hardware verification:** RAM-only v5 boot successfully charged near full at about 4.477 V, 27.9 °C and 327–314 mA, without the false cutoff. The phone was rebooted to Android; no partitions were flashed. Full-cycle termination, recharge and thermal fault behavior remain unverified.

The historical [PMI632 charging validation](CHARGING-VALIDATION.md) and
`CAPRI-NATIVE-SMB5-STATUS.md` in the **kernel development repository** remain
separate documentation; neither is bundled into the Nix source patch.
Apply the patch **once** to the pinned kernel revision, not on top of the
already-patched local development tree.

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
- **Networking/containers:** native WireGuard as a module, TUN, veth, bridge,
  macvlan, ipvlan, vxlan, nftables extensions, traffic control/BPF classifiers,
  namespaces, cgroups, block I/O accounting and PSI.
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
The extra Android Binder, Mobile NixOS USB FunctionFS/RNDIS/NCM gadget
functions, and wide legacy netfilter rule set are not required by the current
headless boot and are not enabled by this pass.

## Native storage and boot layout

Capri uses NixOS's built-in `generic-extlinux-compatible` loader, not
systemd-boot. U-Boot loads the kernel, NixOS initramfs and Power DTB from
`/boot` on the same ext4 filesystem as `/`. There is no separate EFI
filesystem and no need to resize or repurpose Android `super`.

The NixOS root filesystem is on the removable SanDisk microSD, not the
Android internal userdata partition. ADB verified `/dev/block/mmcblk1`
(124735488 512-byte sectors) and the current `/dev/block/mmcblk1p1`
(124702720 sectors). NixOS mounts `/dev/disk/by-label/NIXOS_CAPRI` as `/`;
its generated extlinux boot files live in the same ext4 filesystem.

U-Boot's Capri board DT enables removable `sdhc_2` as `mmc1`, and its
`boot_targets=mmc1` setting restricts the extlinux boot scan to the microSD.
The native Linux Power DT also enables `sdhc_2` with the exact Motorola
DVT2 SKU5 board-ID `0x500/0xb200` regulator, GPIO88 card-detect, and
pinctrl settings. The firmware's initial rail state is retained in U-Boot.
These new board changes are in separate Nix source patches
`0002-uboot-capri-microsd-sdhc2.patch` and
`0002-kernel-capri-microsd-sdhc2.patch`.

**Important:** These changes have not yet been tested on the native Linux
boot path. The removable card currently contains about 52 GiB of existing
files; do not overwrite its partition until the data is explicitly cleared
for erasure or a verified backup exists. The rootfs installer must never
write to `/dev/block/mmcblk0` or any internal partition. The ext4 image is
written to the checked `/dev/block/mmcblk1p1` **partition**, not the
whole-disk `/dev/block/mmcblk1` device.

Leave `super`, `userdata`, all Qualcomm firmware and modem NV/calibration
partitions, including `persist`, `prodpersist`, `modemst1`, `modemst2`, `fsg_b`
and `fsc`, and Motorola boot partitions untouched. The U-Boot test is through
RAM-only `fastboot boot`; no slot flashing or Android repartitioning.

**Verification:** Generated extlinux paths and the original source patch
checks passed, but a complete real-NixOS microSD boot and in-device
storage read remain to be hardware-verified.

USB ECM plus SSH is configured for the **normal** native NixOS system.
Early-initrd USB recovery and early-initrd Buffyboard remain unimplemented;
the RAMUI telnet service is not installed in NixOS.

## USB ECM networking and existing SSH authentication

`hosts/capri/usb-ecm.nix` creates the configfs ECM USB network function after
normal NixOS boots. The phone uses `172.16.42.1/24` on `usb0`; NetworkManager
leaves that interface unmanaged while handling Wi-Fi independently.

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

## Ext4 removable microSD rootfs image

`packages.aarch64-linux.capri-rootfs-image` produces a raw, unencrypted ext4
filesystem image using Nixpkgs' `make-ext4-fs.nix`. It contains the real Capri
system closure, its Nix registration manifest and the standard extlinux
kernel/initramfs/Power-DTB boot files. Only the selected initial generation is
included; build-host profiles are not imported.

The Capri host includes only `den.aspects.capri-minimal` from
`modules/aspects/features/capri-minimal.nix`, rather than the shared
`server` role (which imports the entire development toolchain). The initial
image retains the native Qualcomm/Motorola hardware and charging modules,
Wi-Fi firmware/startup, Buffyboard, USB ECM and key-only SSH on port 2222,
Tailscale, a restricted firewall, fail2ban, and Nix with flake support.
Teldrive, Podman, QEMU, Rust/Go compilers, desktop themes and editor/AI
packages can be added through the dotfiles flake after the first successful
boot. NixOS installer tools and bundled documentation are disabled; rsync
and strace remain for recovery. The **testing-only Capri minimal image**
uses passwordless `bhunter` console autologin, a locked local password, and
passwordless sudo; SSH remains public-key-only. Normal hosts retain their
existing SOPS-based password authentication.

The earlier full-profile filesystem image was approximately 12.8 GiB, with
an 11.0 GiB system closure (1,943 store paths). This is the **old** image,
not a measured result of the minimal profile. The new closure/image size
cannot be confirmed until the minimal image and its kernel are built.

The output is a single filesystem, **not a whole-disk image**. It contains
no GPT or U-Boot boot image. The builder limits the image to the verified
124702720-sector removable microSD partition, and labels the filesystem
`NIXOS_CAPRI` for the root mount. A first-boot service loads the
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

The result link points to the ext4 filesystem image. Building requires the
Capri kernel but not U-Boot. Writing the image requires a verified,
unmounted removable microSD partition and explicit permission to discard
its existing data. Do not copy an image onto Android's userdata or the
whole-disk device.

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

**Validation:** The production image/system derivations and Capri composition
contract evaluate with no failed assertions. A tiny fixture image built through
the same image builder passed checks for unencrypted ext4, extlinux payload
paths, closure contents and registration manifest. A temporary copy grew to its
backing-file size and passed fsck without partition-table changes. Those payloads
were test fixtures; the real Capri image has not been built, and no kernel or
U-Boot compilation, phone formatting or flashing was performed for this step.

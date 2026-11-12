# Capri source patchset for native NixOS

These are **source patches**, not prebuilt kernel/U-Boot binaries. Pin and fetch the source revisions below in Nix; apply each patch using `patches = [ ... ]` (or an equivalent patch phase) before compilation.

## U-Boot: `0001-uboot-motorola-capri-upstream-v2026.07.patch`

- Base: official [U-Boot](https://github.com/u-boot/u-boot), tag `v2026.07`, commit `ece349ade2973e220f524ce59e59711cc919263f` (verified locally with `git rev-parse v2026.07^{commit}`).
- Patch exports commits `v2026.07..592c95f5ce654b153e1e95c416887ccee2063510` from the existing `capri-upstream-uboot` tree.
- Contains Qualcomm ABL handoff support, protected framebuffer handling, Capri configuration/DT and boot menu, EFI fixes, and supporting documentation.
- Compiling it will still require the Capri build configuration (`qcom_defconfig` plus the added `motorola-capri.config`) and packaging `u-boot.bin` into the Motorola Android header-v3 `boot.img` with `mkbootimg`. This patch does not by itself create the final boot.img.
- Sanity check on the current patched tree: `git apply --reverse --check <patch>`; on a clean checkout of the base tag: `git apply --check <patch>`.

The Nix package overlays `uboot/default.env` and enables direct Linux boot with
`sysboot`/`booti`, raw initramfs and read-only ext4 support. It disables eMMC,
filesystem, GPT, flashing, capsule and persistent-environment write paths.
The default boot command checks the verified userdata PARTUUID before reading
`/boot/extlinux/extlinux.conf` from eMMC partition 77. Load addresses come from
Snapdragon's normal runtime memory allocator, not fixed addresses.

The Android header-v3 U-Boot image's empty ramdisk is only a packaging
placeholder. NixOS's real initramfs is loaded from the ext4 root filesystem.

## Kernel: `0001-kernel-capri-power-variant.patch`

- Base: [michaelmcallister/linux-motorola-capri](https://github.com/michaelmcallister/linux-motorola-capri), branch `capri-7.2`, commit `232c314e8909dd77395b2c553e7dda2232e4a4cc` (the upstream Capri kernel source containing drivers and a 7.2.9 Linux tree).
- The working `capri-build-src/` directory was copied from this source family and had **four additional source changes**. This patch captures the complete difference excluding build products:
  1. `arch/arm64/boot/dts/qcom/Makefile`
  2. `arch/arm64/boot/dts/qcom/capri-power-battery.dtsi` (new)
  3. `arch/arm64/boot/dts/qcom/sm4250-motorola-capri-power.dts` (new)
  4. `drivers/power/supply/capri-pmi632-battery.c`
- The separate local documentation-only kernel commit `099b491896d8989e633c8b35bf1c48ceaa185d55` is *not* a prerequisite for compilation and is not included.
- The Nix derivation generates its configuration from the standard ARM64 `defconfig`, Nixpkgs' common kernel settings and declarative Capri `structuredExtraConfig` overrides. It installs matching modules and builds the Power DTB before generating `include/generated/capri-dtb.h` for `Image`.
- Sanity check: `git apply --check <patch>` against the pinned Capri kernel checkout.

`0002-kernel-capri-config-dependencies.patch` seeds built-in Qualcomm LLCC/OCMEM,
backlight and APR support in the standard defconfig. These dependencies must
already permit built-in DRM/audio before Nixpkgs' interactive configuration
generator reaches the drivers. This follows the dependency seed approach used
by chayleaf's OnePlus configuration; it does not replace the shared NixOS
settings or disable strict checking.

## Important

- **Do not apply patches twice**; the earlier development source trees already contain the exported Power and U-Boot changes, but not necessarily the separate configuration dependency seed patch.
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

The Nix kernel derivation uses `buildLinux` with the pinned source's standard
ARM64 `defconfig`, Nixpkgs' common configuration and declarative Capri hardware
overrides in `kernel/default.nix`. Automatic module expansion is enabled.
The stripped `motorola_capri_defconfig` is not the baseline: its disabled parent
features prevent common NixOS settings from being selected. Required overrides
remain strictly checked rather than silently ignored.

A device defconfig is also a valid starting point when combined with explicit
NixOS requirements. [Mobile NixOS](https://github.com/mobile-nixos/mobile-nixos/blob/development/modules/kernel-config.nix)
uses a curated required-settings layer over device configurations rather than
requiring the generic ARM64 defconfig. Capri uses the standard baseline here
to retain the broader Nixpkgs common feature set.

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

Configuration-only generation passed with `enableCommonConfig = true`,
`autoModules = true` and strict option checking. The generated file retains
Capri boot/battery/display, built-in eMMC/ext4 and USB support, modular
touchscreen/Wi-Fi/remoteproc drivers, and the shared security/network features.
RPMB is built in so that the MMC block driver can also be built in.

Both IPv4 and IPv6 iptables rpfilter modules are enabled, resolving the earlier
kernel/firewall capability blocker without weakening the firewall policy.
The full Capri `system.build.toplevel.drvPath`, composition contract and
initramfs derivation now evaluate with no failed assertions. Configuration
generation is not a kernel compilation or hardware boot test.

## Native storage and boot layout

Capri uses NixOS's built-in `generic-extlinux-compatible` loader, not
systemd-boot. U-Boot loads the kernel, NixOS initramfs and Power DTB from
`/boot` on the same ext4 filesystem as `/`. There is no separate EFI
filesystem and no need to resize or repurpose Android `super`.

Live read-only inspection through ADB on `ideapad` verified this XT2127-4's
userdata partition:

| Property | Verified value |
| --- | --- |
| GPT entry / Android name | 77 / `userdata` |
| Android block device | `/dev/block/mmcblk0p77` |
| PARTUUID | `f6eb68be-3488-aaba-703b-eb107625d212` |
| First sector | 24135680 |
| Last sector | 122142686 |
| Sector count / size | 98007007 / 512 bytes |
| Capacity | approximately 46.7 GiB |

`hosts/capri/hardware.nix` declares this PARTUUID as ext4 root. The generated
initrd fstab mounts it as `/`; NixOS writes its extlinux menu and generation
kernel/initramfs/DTB files under `/boot` during installation or activation.
The literal `ext2` argument to U-Boot's `sysboot` selects its ext2/3/4 reader.

**This filesystem has not been created on the phone.** Android currently uses
encrypted F2FS data. A later installation must explicitly authorize erasing and
formatting userdata from a suitable recovery environment; do not try to format
it while Android is using it. Installing U-Boot into `boot_a`/`boot_b` also needs
a separately verified slot and explicit flashing instruction.

No GPT edits are required. Leave `super`, `padA`, `padB`, all Qualcomm firmware
and calibration/NV partitions, and Motorola's bootloader partitions unchanged.
In particular, never erase or format `persist`, `prodpersist`, `modemst1`,
`modemst2`, `fsg_a`, `fsg_b` or `fsc`. Do not write a whole-disk image.
Read-only `sgdisk --verify` found no GPT errors, but reported Motorola's small
partition-entry table, header gap and userdata end alignment; do not normalize
or “repair” these as part of installation.

**Verification:** U-Boot configuration-only generation passed; direct-boot
capabilities are enabled and write/export features are disabled. The standard
NixOS extlinux generator was exercised with temporary path fixtures, checking
kernel/initramfs/Power-DTB paths and kernel parameters. Isolated shell scenarios
checked the partition-UUID guard for the correct UUID, a wrong UUID and missing
eMMC. These are configuration checks, not U-Boot/kernel compilation or physical
boot validation. No device formatting, partition writes or flashing occurred.

Native USB ECM/SSH recovery and early-initrd Buffyboard remain unimplemented;
the RAMUI telnet service is not a secure native recovery path.

## Ext4 userdata image

`packages.aarch64-linux.capri-rootfs-image` produces a raw, unencrypted ext4
filesystem image using Nixpkgs' `make-ext4-fs.nix`. It contains the real Capri
system closure, its Nix registration manifest and the standard extlinux
kernel/initramfs/Power-DTB boot files. Only the selected initial generation is
included; build-host profiles are not imported.

The output is a single filesystem, **not a whole-disk image**. It contains no GPT
or U-Boot boot image. The builder rejects an image larger than the verified
98007007-sector userdata partition.

`hosts/capri/image.nix` enables filesystem auto-resizing inside the existing
userdata partition, while `boot.growPartition = false` prevents automatic GPT
growth. A first-boot service loads `/nix-path-registration`, establishes the
initial NixOS system profile, then removes that marker only after success.

Evaluate without compiling the Capri kernel:

```sh
nix eval --raw .#packages.aarch64-linux.capri-rootfs-image.drvPath
```

After kernel compilation is authorized, build the real image with:

```sh
nix build --out-link result-capri-rootfs .#capri-rootfs-image
```

The result link points directly to the ext4 filesystem image. Building it
requires the Capri kernel but not the U-Boot package. Flashing is a separate,
destructive operation requiring explicit authorization and a verified userdata
target; no flashing script or automatic device writes are provided.

The builder does not copy runtime age keys, decrypted secrets or modem NV
snapshots. Before first boot, provision the existing NixOS SOPS age key at
`/var/lib/sops-nix/key.txt` with mode `0600`, through an explicitly authorized
installation/recovery procedure. Shared `neededForUsers` secrets depend on it.

**Validation:** The production image/system derivations and Capri composition
contract evaluate with no failed assertions. A tiny fixture image built through
the same image builder passed checks for unencrypted ext4, extlinux payload
paths, closure contents and registration manifest. A temporary copy grew to its
backing-file size and passed fsck without partition-table changes. Those payloads
were test fixtures; the real Capri image has not been built, and no kernel or
U-Boot compilation, phone formatting or flashing was performed for this step.

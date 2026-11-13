#!/usr/bin/env python3
"""Package the default-on Capri Power kernel with the known-good RAMUI v7 initramfs.

Never flash partitions. The output image has NO battery charging kernel parameters:
the Power model is selected from its embedded device tree by the driver.
Only the new test output is created; the previous RAMUI image is immutable.
"""
import hashlib
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

REPOS = Path(__file__).resolve().parents[4]
OUTPUT = REPOS / "capri-initfs-output"
KERNEL_SRC = REPOS / "capri-build-src"
OLD_BOOT = OUTPUT / "boot-ramui-qmi-services-v7.img"
OLD_KERNEL = KERNEL_SRC / "out-power/Image.capri"
RAW_KERNEL = KERNEL_SRC / "out-power/arch/arm64/boot/Image"
WRAPPER = KERNEL_SRC / "scripts/capri/wrap-image.py"
NEW_WRAPPED = OUTPUT / "Image.capri-power-default"
NEW_BOOT = OUTPUT / "boot-ramui-power-default-charging.img"

OLD_BOOT_SHA = "084a716bde925b83cabbf500143d2ec42aae24a0d2e1e804cd9cf1405c0d20dd"
OLD_KERNEL_SHA = "e05c89043a1a539b99acffca22f4a90c0b60828855dcafb5d978164a5e1517b3"
OLD_RAW_KERNEL_SHA = "0298260cc1184d0d2d46c75e4a65bb5310b23b7a81992cd4872f0dbc6d2bd650"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def inspect_boot(blob: bytes):
    if blob[:8] != b"ANDROID!":
        raise ValueError("Not an Android boot image")
    kernel_len, ramdisk_len = struct.unpack_from("<II", blob, 8)
    version = struct.unpack_from("<I", blob, 40)[0]
    if version != 3:
        raise ValueError(f"Unexpected Android header version {version}")
    cmdline = blob[44:1580].split(b"\x00", 1)[0].decode("ascii")
    kernel = blob[4096:4096 + kernel_len]
    ramdisk_start = 4096 + ((kernel_len + 4095) // 4096) * 4096
    ramdisk = blob[ramdisk_start:ramdisk_start + ramdisk_len]
    if len(kernel) != kernel_len or len(ramdisk) != ramdisk_len:
        raise ValueError("Boot image payload truncated")
    return cmdline, kernel, ramdisk


def main():
    if NEW_BOOT.exists() or NEW_WRAPPED.exists():
        raise SystemExit("Refusing to overwrite existing Power default-charge image")

    old = OLD_BOOT.read_bytes()
    if sha(old) != OLD_BOOT_SHA:
        raise SystemExit("RAMUI v7 base checksum differs")
    if sha(OLD_KERNEL.read_bytes()) != OLD_KERNEL_SHA:
        raise SystemExit("Baseline wrapper checksum differs")
    old_cmdline, old_embedded_kernel, old_ramdisk = inspect_boot(old)
    if sha(old_embedded_kernel) != OLD_KERNEL_SHA:
        raise SystemExit("RAMUI v7 kernel differs from known-good baseline")
    if "capri_pmi632_battery.charging=0" not in old_cmdline:
        raise SystemExit("Expected old RAMUI lockout parameter missing")

    # Preserve ALL base boot arguments except prior battery overrides.
    cmdline = " ".join(
        arg for arg in old_cmdline.split()
        if not arg.startswith("capri_pmi632_battery.charging=")
        and not arg.startswith("capri_pmi632_battery.power_charging=")
    )
    if "capri_pmi632_battery." in cmdline or cmdline == old_cmdline:
        raise SystemExit("Failed to generate parameter-free boot command line")

    raw = RAW_KERNEL.read_bytes()
    if sha(raw) == OLD_RAW_KERNEL_SHA or len(raw) < 10_000_000:
        raise SystemExit("Rebuilt Power kernel missing")
    if raw[56:60] != b"ARM\x64":
        raise SystemExit("Rebuilt kernel is not an ARM64 Image")

    source = (KERNEL_SRC / "drivers/power/supply/capri-pmi632-battery.c").read_text()
    required = (
        "static bool charging = true;",
        'device_property_read_bool(dev, "motorola,capri-power-battery")',
        "capri_power_set_limits_disabled(chip);",
        "capri_power_charge_update(chip)",
    )
    if any(symbol not in source for symbol in required):
        raise SystemExit("Source does not include the default Power charger path")
    if "static bool power_charging" in source:
        raise SystemExit("Unexpected separate Power charging parameter remains")

    try:
        subprocess.run(
            [sys.executable, str(WRAPPER), str(RAW_KERNEL), str(NEW_WRAPPED)],
            check=True,
        )
        kernel = NEW_WRAPPED.read_bytes()
        if len(kernel) <= len(raw) or sha(kernel) == OLD_KERNEL_SHA:
            raise RuntimeError("New kernel wrapper not distinguishable from baseline")

        with tempfile.TemporaryDirectory(prefix="capri-power-default-") as temp:
            ramdisk_file = Path(temp) / "initramfs.gz"
            ramdisk_file.write_bytes(old_ramdisk)
            subprocess.run([
                "mkbootimg", "--header_version", "3",
                "--kernel", str(NEW_WRAPPED),
                "--ramdisk", str(ramdisk_file),
                "--cmdline", cmdline,
                "--output", str(NEW_BOOT),
            ], check=True)

        result = NEW_BOOT.read_bytes()
        out_cmdline, out_kernel, out_ramdisk = inspect_boot(result)
        if out_cmdline != cmdline or out_kernel != kernel or out_ramdisk != old_ramdisk:
            raise RuntimeError("New boot image does not match expected inputs")
        if sha(OLD_BOOT.read_bytes()) != OLD_BOOT_SHA:
            raise RuntimeError("Known-good RAMUI v7 image changed")
    except Exception:
        NEW_WRAPPED.unlink(missing_ok=True)
        NEW_BOOT.unlink(missing_ok=True)
        raise

    print(f"original_kernel_sha256: {OLD_KERNEL_SHA}")
    print(f"new_raw_kernel_sha256: {sha(raw)}")
    print(f"new_wrapped_kernel_sha256: {sha(kernel)}")
    print(f"new_boot_sha256: {sha(result)}")
    print(f"unchanged_ramdisk_sha256: {sha(old_ramdisk)}")
    print(f"new_cmdline: {cmdline}")
    print(f"new_boot: {NEW_BOOT}")
    print("PASS: Android header v3, new kernel, unchanged RAMUI ramdisk")
    print("PASS: no battery charging kernel parameters; driver default-on")


if __name__ == "__main__":
    main()

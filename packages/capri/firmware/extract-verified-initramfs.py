#!/usr/bin/env python3
"""Create a deterministic firmware-only tar asset from the proven Capri RAM test.

Do not include modem NV partition captures. Input is the existing v8 diagnostic
initramfs, which already contains validated stock Motorola firmware and BDF.
"""
import argparse
import gzip
import hashlib
import io
from pathlib import Path
import tarfile

PREFIXES = ("lib/firmware/", "etc/wifi/")
NEEDED = {
    "lib/firmware/wlanmdsp.mbn",
    "lib/firmware/modem.mdt",
    "lib/firmware/adsp2.mdt",
    "lib/firmware/ath10k/WCN3990/hw1.0/board-2.bin",
    "lib/firmware/ath10k/WCN3990/hw1.0/firmware-5.bin",
}
def aligned(n):
    return (n + 3) & ~3
def firmware_from_cpio(blob):
    offset = 0
    found = {}
    while offset + 110 <= len(blob):
        hdr = blob[offset:offset+110]
        if hdr[:6] not in (b"070701", b"070702"):
            raise ValueError(f"Invalid newc archive at offset {offset}")
        fields = [int(hdr[6+i*8:14+i*8], 16) for i in range(13)]
        mode, size, namesize = fields[1], fields[6], fields[11]
        start = offset + 110
        name_raw = blob[start:start+namesize]
        if len(name_raw) != namesize or not name_raw.endswith(b"\0"):
            raise ValueError("Truncated filename")
        name = name_raw[:-1].decode("utf-8")
        data_at = aligned(start + namesize)
        end = data_at + size
        if end > len(blob):
            raise ValueError("Truncated CPIO file")
        if name == "TRAILER!!!":
            break
        if name.startswith(PREFIXES) and mode & 0o170000 == 0o100000:
            if name in found:
                raise ValueError(f"Duplicate firmware file: {name}")
            found[name] = blob[data_at:end]
        offset = aligned(end)
    absent = NEEDED - found.keys()
    if absent:
        raise ValueError(f"Missing critical firmware: {sorted(absent)}")
    return found

def main():
    p = argparse.ArgumentParser()
    p.add_argument("input", type=Path)
    p.add_argument("output", type=Path)
    args = p.parse_args()
    data = gzip.decompress(args.input.read_bytes())
    files = firmware_from_cpio(data)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(args.output, "w:xz", format=tarfile.PAX_FORMAT, preset=6) as tar:
        for name, content in sorted(files.items()):
            info = tarfile.TarInfo(name)
            info.mode = 0o644
            info.uid = 0
            info.gid = 0
            info.mtime = 1
            info.size = len(content)
            tar.addfile(info, io.BytesIO(content))
    print(f"Captured {len(files)} firmware/config files (NO modem NV partitions)")
    print(f"SHA256 {hashlib.sha256(args.output.read_bytes()).hexdigest()} {args.output}")
if __name__ == "__main__":
    main()

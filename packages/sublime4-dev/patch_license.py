#!/usr/bin/env python3
"""
Patch Sublime Text 4 Linux x64 license checks.
Uses byte signatures to find targets across builds 4200–4205+.
"""

import re
import struct
import sys
from pathlib import Path


def read(path):
    with open(path, "rb") as f:
        return bytearray(f.read())


def write(path, data):
    with open(path, "wb") as f:
        f.write(data)


def as_hex(b):
    return "".join(f"{x:02x}" for x in b)


def sig_find_exact(data, hex_str, offset=0):
    """Fast search for exact byte sequence."""
    pat = bytes.fromhex(hex_str)
    i = data.find(pat)
    if i == -1:
        raise ValueError(f"Pattern not found: {hex_str}")
    return i + offset


def sig_find_n_exact(data, hex_str, n, offset=0):
    """Find exactly N occurrences of exact byte sequence."""
    pat = bytes.fromhex(hex_str)
    matches = []
    start = 0
    while True:
        i = data.find(pat, start)
        if i == -1:
            break
        matches.append(i + offset)
        start = i + 1
    if len(matches) != n:
        raise ValueError(f"Expected {n} matches of {hex_str}, found {len(matches)}")
    return matches


def sig_find_unique(data, sig_str, offset=0):
    """Find exactly one match for signature with ? wildcards (fast)."""
    parts = sig_str.split()
    # Build regex: each ? becomes .{1}, each hex byte becomes literal
    regex = b""
    for p in parts:
        if p == "?":
            regex += b"."
        else:
            regex += re.escape(bytes.fromhex(p))
    matches = [(m.start() + offset) for m in re.finditer(regex, bytes(data))]
    if len(matches) == 0:
        raise ValueError(f"Pattern not found: {sig_str}")
    if len(matches) > 1:
        raise ValueError(f"Multiple ({len(matches)}) matches for: {sig_str}")
    return matches[0]


def sig_find_n(data, sig_str, n, offset=0):
    """Find exactly N matches for pattern with wildcards."""
    parts = sig_str.split()
    regex = b""
    for p in parts:
        if p == "?":
            regex += b"."
        else:
            regex += re.escape(bytes.fromhex(p))
    matches = [(m.start() + offset) for m in re.finditer(regex, bytes(data))]
    if len(matches) != n:
        raise ValueError(f"Expected {n} matches, found {len(matches)} for: {sig_str}")
    return matches


def resolve_call(data, call_offset):
    rel = struct.unpack("<i", data[call_offset + 1 : call_offset + 5])[0]
    return call_offset + 5 + rel


def find_func_start(data, offset, max_lookback=0x200):
    for i in range(offset, max(0, offset - max_lookback), -1):
        if data[i] == 0x55:
            return i
        if data[i] == 0x41 and i + 1 < len(data) and data[i + 1] in (0x53, 0x54, 0x55, 0x56, 0x57):
            return i
    return offset


def detect_version(data):
    m = re.search(rb"sublime_text_(\d{4})", data)
    return int(m.group(1)) if m else None


DEV_VERSIONS = {
    4109, 4110, 4111, 4112, 4114, 4115, 4116, 4117, 4118, 4119, 4120,
    4122, 4123, 4124, 4125, 4127, 4128, 4129, 4130, 4131, 4134, 4136,
    4137, 4138, 4139, 4140, 4141, 4145, 4146, 4147, 4148, 4149, 4150,
    4153, 4154, 4155, 4156, 4158, 4159, 4160, 4164, 4165, 4167, 4168,
    4170, 4171, 4172, 4173, 4174, 4175, 4177, 4178, 4181, 4183, 4184,
    4185, 4187, 4188, 4190, 4191, 4194, 4195, 4196, 4198, 4199, 4205,
}


def patch_is_license_valid(data, version):
    """
    4200: is_license_valid IS the validation function. Patch to ret0.
    4205+: is_license_valid is the button handler — do NOT patch.
    """
    if version > 4200:
        return []

    sig = "554157415641554154534881ec48240000"
    off = sig_find_exact(data, sig)
    data[off : off + 4] = bytes.fromhex("4831c0c3")
    return [("is_license_valid", off, "ret0")]


def patch_persistent_checks(data, version):
    """
    4200: timer-based — mov edx, 0x1388; call; mov edx, 0x3A98; call
    4205+: 5x xor regs; call validation_sub_func; cmp eax, 1
    """
    results = []

    # Try 4205+ : 5x xor + CALL + cmp
    sig5 = "31 f6 31 d2 31 c9 45 31 c0 45 31 c9 e8 ? ? ? ? 83 f8 01"
    try:
        offsets = sig_find_n(data, sig5, 2)
        # Resolve target BEFORE overwriting bytes
        target = resolve_call(data, offsets[0] + 12)
        for off in offsets:
            call_off = off + 12
            data[call_off : call_off + 5] = b'\x90' * 5
            results.append(("persistent_check", call_off, "NOP"))
        results.append(("validation_sub_func_target", target, ""))
        return results
    except ValueError:
        pass

    # Try 4200: find two timer+CALL patterns (not adjacent — there's setup code between)
    try:
        off1 = sig_find_exact(data, "ba88130000e8")  # mov edx, 0x1388; call
        call1 = off1 + 5
        data[call1 : call1 + 5] = b'\x90' * 5
        results.append(("persistent_check_1", call1, "NOP"))
    except ValueError:
        raise ValueError("persistent_check_1 not found (timer 0x1388)")

    try:
        off2 = sig_find_exact(data, "ba983a0000e8")  # mov edx, 0x3A98; call
        call2 = off2 + 5
        data[call2 : call2 + 5] = b'\x90' * 5
        results.append(("persistent_check_2", call2, "NOP"))
    except ValueError:
        raise ValueError("persistent_check_2 not found (timer 0x3A98)")

    return results


def patch_validation_sub_func(data, version, known_target=None):
    """Patch core validation to always return valid.
    4200: already handled by patch_is_license_valid (ret0 = valid).
    4205+: patch entry to ret1 (returns 1 = valid)."""
    if version <= 4200:
        return []
    if known_target is None:
        # Must be resolved from persistent_checks signature
        return []

    target = known_target
    if data[target : target + 6] != bytes.fromhex("554157415641"):
        raise ValueError(
            f"validation_sub_func @ {target:x}: unexpected prologue {as_hex(data[target:target+6])}"
        )
    data[target : target + 7] = bytes.fromhex("4831c048ffc0c3")
    return [("validation_sub_func", target, "ret1")]


def patch_thread_check(data, version):
    """
    thread_check_license: sub rsp, 0x418 + mov r14, rdi.
    Both 4200 and 4205 have identical prologue.
    4200: ret0. 4205+: ret1.
    """
    sig = "554157415641554154534881ec180400004989fe"
    off = sig_find_exact(data, sig)
    if data[off : off + 4] != bytes.fromhex("55415741"):
        raise ValueError(f"thread_check @ {off:x}: unexpected prologue")

    patch = bytes.fromhex("4831c0c3" if version <= 4200 else "4831c048ffc0c3")
    data[off : off + len(patch)] = patch
    return [("thread_check", off, "ret0" if version <= 4200 else "ret1")]


def patch_thread_notify(data, version):
    """
    Notification thread. Starts with 0x41.
    Pattern: sub rsp, 0x308; mov rbx, rdi; lea rdi, [rip]
    Patch first byte to C3 (ret).
    """
    sig = "4881ec080300004889fb488d3d"
    off = sig_find_exact(data, sig)
    func_start = find_func_start(data, off, 0x20)
    if data[func_start] != 0x41:
        raise ValueError(f"thread_notify @ {func_start:x}: expected first byte 41")
    data[func_start] = 0xC3
    return [("thread_notify", func_start, "C3")]


def patch_crash_reporter(data, version):
    """
    4200: push rbp; ...; sub rsp, 0x548
    4205+: push r14; push rbx; push rax; lea rdi,[rip]; lea rsi,[rip]; lea rbx,[rip]
    """
    if version <= 4200:
        sig = "554157415641554154534881ec48050000"
        off = sig_find_exact(data, sig)
        data[off : off + 4] = bytes.fromhex("4831c0c3")
        return [("crash_reporter", off, "ret0")]
    else:
        sig = "41565350488d3d ? ? ? ? 48 8d 35 ? ? ? ? 48 8d 1d ? ? ? ?"
        off = sig_find_unique(data, sig)
        if data[off : off + 4] != bytes.fromhex("41565350"):
            raise ValueError(f"crash_reporter @ {off:x}: unexpected prologue")
        data[off : off + 4] = bytes.fromhex("4831c0c3")
        return [("crash_reporter", off, "ret0")]


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <sublime_text> [--dry-run]")
        sys.exit(1)

    path = Path(sys.argv[1])
    dry_run = "--dry-run" in sys.argv
    data = read(path)
    version = detect_version(data)

    if version is None:
        print("ERROR: Could not detect Sublime Text version")
        sys.exit(1)

    channel = "dev" if version in DEV_VERSIONS else "stable"
    print(f"Sublime Text build {version} ({channel})")
    print(f"Binary: {path}  ({len(data)} bytes)")

    all_patches = []
    errors = []

    # Run patch functions
    for name, fn in [
        ("is_license_valid", lambda d, v: patch_is_license_valid(d, v)),
        ("persistent_checks", lambda d, v: patch_persistent_checks(d, v)),
        ("validation_sub_func", lambda d, v: patch_validation_sub_func(d, v, None)),
        ("thread_check", lambda d, v: patch_thread_check(d, v)),
        ("thread_notify", lambda d, v: patch_thread_notify(d, v)),
        ("crash_reporter", lambda d, v: patch_crash_reporter(d, v)),
    ]:
        try:
            result = fn(data, version)
            all_patches.extend(result)
            # If persistent checks gave us the validation target, apply it
            for pname, poff, pinfo in result:
                if pname == "validation_sub_func_target":
                    extra = patch_validation_sub_func(data, version, poff)
                    all_patches.extend(extra)
        except ValueError as e:
            errors.append(f"{name}: {e}")

    # Display results
    display = [x for x in all_patches if x[0] != "validation_sub_func_target"]
    display.sort(key=lambda x: x[1])

    print()
    for name, off, ptype in display:
        print(f"  {off:#010x}: {name:30s} {ptype}")
    print(f"\n{len(display)} patches applied")

    if errors:
        print(f"\nWarnings ({len(errors)}):")
        for e in errors:
            print(f"  {e}")

    if not dry_run:
        write(path, data)
        print(f"\nPatched binary written to {path}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Offline Capri Power telemetry sanity checks; never touches device or PMIC.

This verifies interpolation arithmetic and source-level lockout invariants.
It does not certify current calibration, thermal hardware, or charging safety.
Usage: python3 packages/capri/tests/check-telemetry.py ../capri-build-src/drivers/power/supply/capri-pmi632-battery.c
"""
import argparse
from pathlib import Path
import re


def parse_therm_table(source: str) -> list[tuple[int, int]]:
    block = re.search(
        r"capri_therm_table\[\]\s*=\s*\{(?P<rows>.*?)\n\};",
        source,
        flags=re.DOTALL,
    )
    if block is None:
        raise AssertionError("Thermistor lookup table missing")
    entries = [(int(mv), int(decic)) for mv, decic in
               re.findall(r"\{\s*(\d+)\s*,\s*(-?\d+)\s*\}", block["rows"])]
    assert len(entries) >= 50, "Expected complete OEM temperature lookup table"
    assert all(a[0] > b[0] and a[1] < b[1] for a, b in zip(entries, entries[1:])), (
        "Table must have falling voltage and rising temperature"
    )
    return entries


def sample_temp(microvolts: int, entries: list[tuple[int, int]]) -> int:
    # Mirrors capri_temperature(): processed IIO reading in uV, truncated to mV.
    mv = microvolts // 1000
    assert entries[-1][0] <= mv <= entries[0][0]
    for (hi_mv, hi_temp), (lo_mv, lo_temp) in zip(entries, entries[1:]):
        if mv >= lo_mv:
            return hi_temp + (hi_mv - mv) * (lo_temp - hi_temp) // (hi_mv - lo_mv)
    raise AssertionError("Failed to interpolate in-range ADC value")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("driver", type=Path, help="already-patched Capri battery driver")
    args = parser.parse_args()
    source = args.driver.read_text()
    entries = parse_therm_table(source)
    assert entries[0][1] <= -400 and entries[-1][1] >= 950
    assert sample_temp(441890, entries) == 272
    assert abs(sample_temp(429044, entries) - 282) <= 2
    assert all(sample_temp(uv + 1000, entries) <= sample_temp(uv, entries)
               for uv in range((entries[-1][0] + 1) * 1000,
                               (entries[0][0] - 1) * 1000, 1000))

    probe = source.split("static int capri_probe(", 1)[1].split(
        "static void capri_shutdown", 1
    )[0]
    assert "ret = capri_disable_charging(chip);" in probe
    assert "if (!chip->power_variant) {" in probe
    assert "ret = capri_charger_init(chip);" in probe

    set_fn = source.split("static int capri_set(", 1)[1].split(
        "static int capri_writable", 1
    )[0]
    assert "(!charging || !chip->charger_ready)" in set_fn
    assert "return -EPERM;" in set_fn

    sample_fn = source.split("static int capri_sample(", 1)[1].split(
        "static void capri_poll(", 1
    )[0]
    assert "ret = capri_temperature(chip);" in sample_fn
    assert "if (chip->temperature <= 50)" in sample_fn
    assert "else if (chip->temperature >= 450)" in sample_fn

    print("PASS: monotonically ordered thermistor table and arithmetic")
    print("PASS: 27.2 C and ~28.2 C historical ambient ADC sample checks")
    print("PASS: periodic temperature sampling and health-threshold source invariants")
    print("PASS: charging disabled at probe and Power charger-readiness gate")
    print("NOTE: Offline source checks only; hardware charging remains UNVALIDATED")


if __name__ == "__main__":
    main()

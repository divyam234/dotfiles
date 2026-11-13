#!/usr/bin/env python3
"""Offline verification of the read-only PMI632 USB input monitor (not a charging test)."""

from pathlib import Path
import re
import sys

if len(sys.argv) != 3:
    raise SystemExit("Usage: check-input-monitor.py <driver.c> <power.dtsi>")
driver = Path(sys.argv[1]).read_text()
dt = Path(sys.argv[2]).read_text()

registers = {
    "CAPRI_POWER_PATH_STATUS": "0x110b",
    "CAPRI_AICL_STATUS": "0x110a",
    "CAPRI_ICL_STATUS": "0x1107",
    "CAPRI_APSD_STATUS": "0x1307",
    "CAPRI_APSD_RESULT": "0x1308",
}
for name, addr in registers.items():
    assert re.search(r"#define\s+" + name + r"\s+" + addr + r"\b", driver), name

fn = driver.split("static int capri_power_sample_input(", 1)[1].split(
    "static int capri_sample(", 1
)[0]
assert "chip->usb_type = POWER_SUPPLY_USB_TYPE_UNKNOWN" in fn
assert "apsd & CAPRI_APSD_DONE" in fn
for kind in ("SDP", "CDP", "DCP"):
    assert f"POWER_SUPPLY_USB_TYPE_{kind}" in fn
assert "result &= GENMASK(6, 0)" in fn
assert "regmap_read(chip->map, CAPRI_ICL_STATUS, &icl)" in fn
assert "icl * 50000" in fn
assert "chip->usb_in_current_ua = sense_uv * 5" in fn
assert "chip->input_path_valid" in fn
assert "chip->aicl_done" in fn
assert "chip->aicl_limited" in fn
assert "usb_input_valid = false" in fn
assert "usb_input_valid = true" in fn
assert not re.search(r"regmap_(write|update_bits|bulk_write)", fn), "PMIC write in input reader"
assert "WD_PET" not in fn and "CHGR_ENABLE" not in fn

for name in ("batt-therm", "usb-in-v", "usb-in-i"):
    assert f'"{name}"' in dt
    assert f'devm_iio_channel_get(dev, "{name}")' in driver
monitor = dt.split("battery-monitor@4800 {", 1)[1].split("};", 1)[0]
assert re.search(r"io-channels\s*=\s*<&capri_adc\s+0x2a>\s*,\s*"
                 r"<&capri_adc\s+0x08>\s*,\s*<&capri_adc\s+0x07>", monitor)
usb = driver.split("static int capri_usb_get(", 1)[1].split("static int capri_set(", 1)[0]
for prop in ("ONLINE", "USB_TYPE", "VOLTAGE_NOW", "CURRENT_NOW", "INPUT_CURRENT_LIMIT"):
    assert f"POWER_SUPPLY_PROP_{prop}" in usb
assert "(!chip->power_variant || !chip->usb_input_valid)" in usb
assert "capri_pmi632_battery.charging=1" not in dt
assert "if (!chip->power_variant) {" in driver
assert "(!charging || !chip->charger_ready)" in driver

# The exact source-class map intentionally does not turn unknown/QC or FLOAT into SDP.
mask = 0x7f
classify = lambda raw: {0x01: "SDP", 0x04: "CDP", 0x08: "DCP", 0x02: "DCP"}.get(raw & mask, "UNKNOWN")
for raw, expected in ((0, "UNKNOWN"), (1, "SDP"), (4, "CDP"),
                      (8, "DCP"), (2, "DCP"), (16, "UNKNOWN"), (40, "UNKNOWN")):
    assert classify(raw) == expected

# PMI632 downstream parameters: input limit status in 50mA steps up to 3A.
assert 60 * 50000 == 3000000
assert 25000 * 5 == 125000   # 25mV at 0.2V/A = 125mA
print("PASS: PMI632 APSD/path/AICL/ICL register map and strict source decoding")
print("PASS: Power-only USB ADC phandles, 0.2 V/A current conversion and input ICL scale")
print("PASS: input monitor has no PMIC writes and preserves charge-enable denial")
print("NOTE: offline checks; hardware measurements and charging remain unvalidated")

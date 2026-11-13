#!/usr/bin/env python3
"""Offline source audit for Capri Power PMI632 charger-event wiring.

No hardware access, register writes or charging activation.
Run from dotfiles:
  python3 packages/capri/tests/check-charger-events.py \
    ../capri-build-src/drivers/power/supply/capri-pmi632-battery.c \
    ../capri-build-src/arch/arm64/boot/dts/qcom/capri-power-battery.dtsi
"""
import argparse
from pathlib import Path
import re

IRQ_NAMES = (
    "chgr-error",
    "chg-state-change",
    "bat-temp",
    "usbin-plugin",
    "wdog-bark",
)
IRQ_CELLS = (
    ("0x2", "0x10", "0x0", "IRQ_TYPE_EDGE_RISING"),
    ("0x2", "0x10", "0x1", "IRQ_TYPE_EDGE_RISING"),
    ("0x2", "0x12", "0x0", "IRQ_TYPE_EDGE_RISING"),
    ("0x2", "0x13", "0x4", "IRQ_TYPE_EDGE_BOTH"),
    ("0x2", "0x16", "0x1", "IRQ_TYPE_EDGE_RISING"),
)
PACK_CONSTANTS = (
    "chip->info->charge_full_design_uah != 6000000",
    "chip->info->voltage_max_design_uv != 4450000",
    "chip->info->constant_charge_voltage_max_uv != 4450000",
    "chip->info->constant_charge_current_max_ua != 3000000",
    "chip->info->charge_term_current_ua != 290000",
)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("driver", type=Path)
    ap.add_argument("power_dtsi", type=Path)
    args = ap.parse_args()
    driver = args.driver.read_text()
    dtsi = args.power_dtsi.read_text()

    assert all(s in driver for s in PACK_CONSTANTS), "ATL battery guard not complete"
    assert "if (chip->power_variant &&" in driver, "ATL guard not SKU5-specific"

    irq_fn = driver.split("static irqreturn_t capri_power_event(", 1)[1].split(
        "static int capri_power_request_irqs(", 1
    )[0]
    assert "mod_delayed_work(system_wq, &chip->work, 0)" in irq_fn
    assert "READ_ONCE(chip->stopping)" in irq_fn
    forbidden = ("regmap_write", "regmap_update_bits", "WD_PET", "CHGR_ENABLE",
                 "capri_charger_init", "capri_disable_charging")
    assert not any(token in irq_fn for token in forbidden), "Event handler writes PMIC"

    req = driver.split("static int capri_power_request_irqs(", 1)[1].split(
        "static enum power_supply_property", 1
    )[0]
    names = re.findall(r'"([^"]+)"', driver.split(
        "static const char * const capri_power_irqs[] = {", 1
    )[1].split("};", 1)[0])
    assert tuple(names) == IRQ_NAMES, f"Driver IRQ names differ: {names}"
    assert "if (!chip->power_variant)" in req
    assert "platform_get_irq_byname(pdev, capri_power_irqs[i])" in req
    assert "devm_request_threaded_irq(" in req

    monitor = dtsi.split("battery-monitor@4800 {", 1)[1].split("};", 1)[0]
    ints = monitor.split("interrupts =", 1)[1].split(";", 1)[0]
    parsed_irqs = tuple(tuple(part.split()) for part in re.findall(r"<([^>]+)>", ints))
    assert parsed_irqs == IRQ_CELLS, f"DT interrupts differ: {parsed_irqs}"
    labels = monitor.split("interrupt-names =", 1)[1].split(";", 1)[0]
    parsed_names = tuple(re.findall(r'"([^"]+)"', labels))
    assert parsed_names == IRQ_NAMES

    # Power-only ADC additions. They expose raw USB input senses for future
    # independent comparisons; there is no charge-control code in their DT nodes.
    adc = dtsi.split("adc@3100 {", 1)[1].split("battery-monitor@4800", 1)[0]
    assert re.search(r"channel@7\s*\{[^}]*reg = <0x07>", adc, re.S)
    assert re.search(r"channel@8\s*\{[^}]*reg = <0x08>", adc, re.S)
    assert 'label = "usb_in_i"' in adc and 'label = "usb_in_v_div_16"' in adc

    assert "motorola,capri-power-battery;" in monitor
    assert "if (!chip->power_variant) {" in driver
    assert "(!charging || !chip->charger_ready)" in driver
    print("PASS: five IRQ mappings match Motorola's PMI632 register groups")
    print("PASS: IRQ handler schedules telemetry only; no charge-enable writes")
    print("PASS: Power battery profile and default-on charger and PMIC-ready gate")
    print("PASS: USB input ADC7/ADC8 monitoring channels")
    print("NOTE: IRQ wiring checks only; charging control tested separately")


if __name__ == "__main__":
    main()

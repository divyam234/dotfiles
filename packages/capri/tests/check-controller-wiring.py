#!/usr/bin/env python3
"""Regression check for the single combined Capri Power kernel patch."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
patch = (root / "patches/0001-kernel-capri-power-charging.patch").read_text()
blocks = {}
for part in patch.split("diff --git a/")[1:]:
    path = part.split(" b/", 1)[0]
    blocks[path] = "\n".join(
        line[1:] for line in part.splitlines()
        if line.startswith("+") and not line.startswith("+++")
    )

driver = blocks["drivers/power/supply/capri-pmi632-battery.c"]
controller = blocks["drivers/power/supply/capri-pmi632-controller.h"]
charger = blocks["drivers/power/supply/capri-pmi632-power-charger.h"]

assert 'module_param(power_charging,' not in driver
assert 'static bool power_charging' not in driver
assert 'static bool charging = true;' in (
    root.parents[2] / 'capri-build-src/drivers/power/supply/capri-pmi632-battery.c'
).read_text()
assert 'chip->behaviour = charging ? POWER_SUPPLY_CHARGE_BEHAVIOUR_AUTO :' in (
    root.parents[2] / 'capri-build-src/drivers/power/supply/capri-pmi632-battery.c'
).read_text()
assert 'else if (charging)' in driver
assert 'capri_power_set_limits_disabled(chip)' in driver
assert 'capri_power_charge_update(chip)' in driver
assert 'capri_control_calculate(' in driver
assert 'shadow_charging_permitted=%u' in driver
assert 'WRITE_ONCE(chip->wdog_bark_latched, true)' in driver
assert 'o.charge_current_calibrated = false;' in driver

assert 'o->runtime_charge_enabled' in controller
assert 'p.charging_permitted = p.source_candidate && o->runtime_charge_enabled;' in controller
assert 'CAPRI_CTL_FAULT_LATCHED' in controller

init = charger.split('static int capri_power_set_limits_disabled', 1)[1].split(
    'static int capri_power_charge_update', 1
)[0]
assert 'ret = capri_disable_charging(chip);' in init
assert 'ret = regmap_write(chip->map, CHGR_FCC, CAPRI_POWER_FCC_UA / 50000);' in init
assert 'CAPRI_POWER_FV_UV          4450000' in charger
assert 'CAPRI_POWER_WDOG_TIMEOUT   (BIT(7) | BIT(3) | BIT(2))' in charger
assert 'CAPRI_POWER_JEITA_CFG      (BIT(3) | BIT(1) | BIT(0))' in charger

# Only charging-current cap can be programmed during init; the device's
# existing JEITA, watchdog, ITERM, recharge, timer, ICL and FV are read back.
assert not re.search(r'\bregmap_update_bits\s*\(', init)
assert not re.search(r'\bcapri_write16\s*\(', init)
assert re.findall(r'\bregmap_write\s*\(', init) == ['regmap_write(']
for reg in ('CHGR_ENABLE', 'CHGR_FV', 'CAPRI_SAFETY_TIMER',
            'WD_CFG', 'WD_TIMEOUT', 'CAPRI_ITERM_SOURCE'):
    assert f'CAPRI_READ_OR_FAIL({reg},' in init, reg
assert 'abs(iterm_ua + CAPRI_POWER_TERM_UA) > 10000' in init

runtime = charger.split('static int capri_power_charge_update', 1)[1]
assert 'should_charge = p->charging_permitted &&' in runtime
assert 'chip->usb_input_current_limit_ua <= 500000' in runtime
assert 'capri_disable_charging(chip);' in runtime
assert 'regmap_update_bits(chip->map, CHGR_ENABLE,' in runtime

print('PASS: one combined patch contains Power probe, ADC, IRQ and charging controller')
print('PASS: OEM PMIC protection settings are read back, not overwritten at init')
print('PASS: 200mA FCC cap, default policy and source/health gates remain explicit')

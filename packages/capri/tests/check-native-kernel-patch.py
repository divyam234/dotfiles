#!/usr/bin/env python3
"""Check that Nix uses the single native Capri SMB5/QGauge kernel patch."""
from pathlib import Path

root = Path(__file__).resolve().parent.parent
patch_path = root / "patches/0001-kernel-capri-native-smb5.patch"
kernel_patches = sorted((root / "patches").glob("*kernel*.patch"))
assert kernel_patches == [patch_path], kernel_patches

patch = patch_path.read_text()
blocks = {}
for part in patch.split("diff --git a/")[1:]:
    name = part.split(" b/", 1)[0]
    blocks[name] = part


def additions(name: str) -> str:
    return "\n".join(
        line[1:] for line in blocks[name].splitlines()
        if line.startswith("+") and not line.startswith("+++")
    )


old_driver = blocks["drivers/power/supply/capri-pmi632-battery.c"]
assert "deleted file mode" in old_driver
assert "config BATTERY_CAPRI_PMI632" not in additions("drivers/power/supply/Kconfig")

charger = additions("drivers/power/supply/qcom_smbx.c")
gauge = additions("drivers/power/supply/qcom_qg.c")
policy = additions("drivers/power/supply/qcom_pmi632_policy.h")
assert all(not path.endswith('.md') and not path.startswith('arch/arm64/configs/')
           for path in blocks), 'Nix patch must not carry docs or defconfig changes'

assert "pmi632_match_data" in charger
assert "chip->pmi632_float_uv + 40000" in charger
assert "SMB5_CHARGER_ERROR_STATUS_BAT_OV_BIT" in charger
assert "pmi632_ov_latched" not in charger
assert "power_supply_get_by_name(\"pmi632-charger\")" in gauge
assert "voltage_max_design_uv" in gauge
assert "pmi632_charge_enable" in policy
assert "pmi632_init_protection" in policy
assert "pmi632_ov_latched" not in policy

assert "arch/arm64/boot/dts/qcom/sm4250-motorola-capri-power.dts" in blocks
assert "arch/arm64/boot/dts/qcom/capri-battery-therm.dtsi" in blocks
nix_kernel = (root / "kernel/default.nix").read_text()
for symbol in (
    'CHARGER_QCOM_SMB2', 'BATTERY_QCOM_QG',
    'GENERIC_ADC_THERMAL', 'NVMEM_SPMI_SDAM',
    'QCOM_LLCC', 'QCOM_OCMEM', 'QCOM_APR',
    'BACKLIGHT_CLASS_DEVICE',
):
    assert f"{symbol} = yes;" in nix_kernel, symbol
assert "BATTERY_CAPRI_PMI632" not in nix_kernel
assert "0001-kernel-capri-native-smb5.patch" in nix_kernel

print("PASS: one kernel patch includes native SMB5, QGauge and Power DTB")
print("PASS: source patch removes the legacy driver and float-voltage latch")
print('PASS: all config flags are set in Nix, no docs/defconfigs in patch')

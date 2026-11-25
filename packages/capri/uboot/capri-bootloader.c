// SPDX-License-Identifier: GPL-2.0-only
/* PM8998-compatible PON reboot-reason encoding, as used by Linux qcom-pon. */
#include <command.h>
#include <dm.h>
#include <dm/ofnode.h>
#include <dm/uclass.h>
#include <power/pmic.h>

static int do_capri_bootloader(struct cmd_tbl *cmdtp, int flag, int argc,
			      char *const argv[])
{
	struct udevice *pmic;
	ofnode pon;
	u32 base;
	int old, value, ret;

	if (!ofnode_device_is_compatible(ofnode_root(), "motorola,capri"))
		return CMD_RET_FAILURE;
	pon = ofnode_by_compatible(ofnode_null(), "qcom,pm8998-pon");
	if (!ofnode_valid(pon) || ofnode_read_u32(pon, "reg", &base))
		return CMD_RET_FAILURE;
	ret = uclass_get_device_by_ofnode(UCLASS_PMIC, ofnode_get_parent(pon), &pmic);
	if (ret) {
		printf("Cannot access PON PMIC: %d\n", ret);
		return CMD_RET_FAILURE;
	}
	/* PON_SOFT_RB_SPARE, GEN2 reason [7:1]; bootloader = 2.
	 * Preserve bit 0. This is a reboot latch, not partition storage.
	 */
	old = pmic_reg_read(pmic, base + 0x8f);
	if (old < 0)
		return CMD_RET_FAILURE;
	ret = pmic_clrsetbits(pmic, base + 0x8f, 0xfe, 2 << 1);
	if (ret)
		goto restore;
	value = pmic_reg_read(pmic, base + 0x8f);
	if (value < 0 || (value & 0xfe) != (2 << 1)) {
		printf("Bootloader reboot reason did not verify\n");
		goto restore;
	}
	printf("Rebooting bootloader\n");
	run_command("reset", 0);
	printf("Reset returned unexpectedly\n");
restore:
	if (pmic_reg_write(pmic, base + 0x8f, old))
		printf("WARNING: could not restore previous PON reboot reason\n");
	return CMD_RET_FAILURE;
}

U_BOOT_CMD(capri_bootloader, 1, 0, do_capri_bootloader,
	   "reboot Capri into the Motorola bootloader", "");

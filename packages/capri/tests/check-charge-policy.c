// SPDX-License-Identifier: GPL-2.0-only
/*
 * Native regression tests for the EXACT pure-C charging-policy helper
 * included in the arm64 kernel. Nothing touches the device or PMIC.
 *
 * cc -std=c11 -Wall -Wextra -Werror \
 *   -I ../capri-build-src/drivers/power/supply \
 *   packages/capri/tests/check-charge-policy.c -o /tmp/capri-policy-test
 * /tmp/capri-policy-test
 */
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include "capri-pmi632-policy.h"

#define PERMANENT (CAPRI_BLOCK_LOCKOUT | CAPRI_BLOCK_JEITA_UNVERIFIED | \
		   CAPRI_BLOCK_WDOG_UNVERIFIED | \
		   CAPRI_BLOCK_ITERM_UNVERIFIED | \
		   CAPRI_BLOCK_QG_UNCALIBRATED | CAPRI_BLOCK_SOURCE_POLICY)

static const struct capri_power_policy_inputs baseline = {
	.battery_present = true,
	.gauge_sample_valid = true,
	.usb_online = true,
	.usb_sample_valid = true,
	.usb_path_valid = true,
	.aicl_done = true,
	.source_is_sdp = true,
	.battery_healthy = true,
	.charger_fault = false,
	.hw_read_valid = true,
	.charge_cmd_disabled = true,
	.watchdog_cfg_matches = true,
	.timer_cfg_matches = true,
	.iterm_cfg_matches = true,
	.hw_charge_limits_match = true,
	.temperature_decic = 261,
	.battery_voltage_uv = 4000000,
	.usb_voltage_uv = 5034000,
	.usb_icl_ua = 500000,
};

static void fails(const char *name, struct capri_power_policy_inputs in,
		  unsigned int bit)
{
	unsigned int got = capri_power_policy_blockers(&in);
	if (!(got & bit) || !(got & CAPRI_BLOCK_LOCKOUT)) {
		fprintf(stderr, "%s: expected blockers 0x%x, got 0x%x\n",
			name, bit, got);
		assert(0);
	}
}

int main(void)
{
	struct capri_power_policy_inputs in = baseline;
	unsigned int blocked = capri_power_policy_blockers(&in);

	assert(blocked == PERMANENT);
	assert(blocked != 0);

	in.battery_present = false;
	fails("no pack", in, CAPRI_BLOCK_NO_BATTERY);
	in = baseline;
	in.gauge_sample_valid = false;
	fails("stale QGauge", in, CAPRI_BLOCK_GAUGE_SAMPLE);
	in = baseline;
	in.usb_online = false;
	fails("no USB", in, CAPRI_BLOCK_NO_USB);
	in = baseline;
	in.usb_sample_valid = false;
	fails("stale USB ADC", in, CAPRI_BLOCK_USB_SAMPLE);
	in = baseline;
	in.usb_path_valid = false;
	fails("suspended USB path", in, CAPRI_BLOCK_INPUT_PATH);
	in = baseline;
	in.aicl_done = false;
	fails("AICL pending", in, CAPRI_BLOCK_AICL_PENDING);
	in = baseline;
	in.source_is_sdp = false;
	fails("DCP/CDP unknown Type-C role", in, CAPRI_BLOCK_SOURCE_UNVERIFIED);
	in = baseline;
	in.usb_icl_ua = 750000;
	fails("source over 500mA", in, CAPRI_BLOCK_INPUT_LIMIT);
	in = baseline;
	in.usb_voltage_uv = 4200000;
	fails("USB brownout", in, CAPRI_BLOCK_INPUT_LIMIT);
	in = baseline;
	in.usb_voltage_uv = 6000000;
	fails("unexpected USB voltage", in, CAPRI_BLOCK_INPUT_LIMIT);
	in = baseline;
	in.temperature_decic = 50;
	fails("cold pack", in, CAPRI_BLOCK_TEMPERATURE);
	in = baseline;
	in.temperature_decic = 450;
	fails("hot pack", in, CAPRI_BLOCK_TEMPERATURE);
	in = baseline;
	in.battery_voltage_uv = 4450000;
	fails("battery reaches pack ceiling", in, CAPRI_BLOCK_VOLTAGE);
	in = baseline;
	in.battery_healthy = false;
	fails("health not good", in, CAPRI_BLOCK_BATTERY_HEALTH);
	in = baseline;
	in.charger_fault = true;
	fails("charger fault", in, CAPRI_BLOCK_CHARGER_FAULT);
	in = baseline;
	in.charge_cmd_disabled = false;
	fails("unexpectedly enabled charge command", in,
	      CAPRI_BLOCK_CMD_NOT_DISABLED);
	in = baseline;
	in.watchdog_cfg_matches = false;
	fails("watchdog mismatch", in, CAPRI_BLOCK_WDOG_CONFIG);
	in = baseline;
	in.timer_cfg_matches = false;
	fails("timer mismatch", in, CAPRI_BLOCK_TIMER_CONFIG);
	in = baseline;
	in.iterm_cfg_matches = false;
	fails("ITERM mismatch", in, CAPRI_BLOCK_ITERM_CONFIG);
	in = baseline;
	in.hw_charge_limits_match = false;
	fails("FCC/FV mismatch", in, CAPRI_BLOCK_HW_CHARGE_LIMITS);
	in = baseline;
	in.hw_read_valid = false;
	blocked = capri_power_policy_blockers(&in);
	assert(blocked & CAPRI_BLOCK_HW_READ_FAILED);
	assert(blocked & CAPRI_BLOCK_CMD_NOT_DISABLED);
	assert(blocked & CAPRI_BLOCK_WDOG_CONFIG);
	assert(blocked & CAPRI_BLOCK_TIMER_CONFIG);
	assert(blocked & CAPRI_BLOCK_ITERM_CONFIG);
	assert(blocked & CAPRI_BLOCK_HW_CHARGE_LIMITS);
	assert(blocked & CAPRI_BLOCK_LOCKOUT);

	puts("PASS: 21 charge policy scenarios, including fail-closed read errors");
	puts("PASS: Power lockout and unvalidated protections are unconditional");
	puts("NOTE: does not enable charging or validate physical protections");
	return 0;
}

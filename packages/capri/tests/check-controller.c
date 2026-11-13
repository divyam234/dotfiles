// SPDX-License-Identifier: GPL-2.0-only
/* Native deterministic tests of the EXACT Capri Power controller header.
 * Build:
 *   cc -std=c11 -O2 -Wall -Wextra -Werror \
 *      -I ../capri-build-src/drivers/power/supply \
 *      packages/capri/tests/check-controller.c -o /tmp/capri-controller-test
 *   /tmp/capri-controller-test
 */
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include "capri-pmi632-controller.h"

static const struct capri_control_observation nominal = {
	.usb_online = true,
	.usb_sample_valid = true,
	.usb_path_valid = true,
	.aicl_done = true,
	.usb_sdp = true,
	.battery_present = true,
	.gauge_valid = true,
	.health_good = true,
	.temperature_decic = 268,
	.battery_voltage_uv = 4000000,
	.usb_voltage_uv = 5032000,
	.usb_icl_ua = 500000,
	.usb_current_ua = 220000,
	.charge_current_calibrated = false,
	.charging_active = false,
};

static void step_fault(const char *name,
		struct capri_control_observation o,
		unsigned int expected)
{
	struct capri_control_state state = {};
	struct capri_control_plan plan;
	int i;

	for (i = 0; i < 4; ++i)
		plan = capri_control_calculate(&state, &o);
	if ((plan.reasons & expected) != expected || plan.source_candidate ||
	    plan.charging_permitted || plan.fcc_ua != 0) {
		fprintf(stderr,
			"%s: reasons=0x%x expected=0x%x candidate=%d FCC=%d\n",
			name, plan.reasons, expected, plan.source_candidate,
			plan.fcc_ua);
		assert(false);
	}
}

int main(void)
{
	struct capri_control_observation o = nominal;
	struct capri_control_state state = {};
	struct capri_control_plan plan;
	int i;
	unsigned int scenarios = 0;

	/* An SDP cable, stable for three 5-second observations, yields
	 * only a *hypothetical* 200mA / 4.45V setpoint. Never authorization.
	 */
	for (i = 1; i <= 3; ++i) {
		plan = capri_control_calculate(&state, &o);
		assert(!plan.charging_permitted);
		if (i < 3)
			assert(plan.reasons & CAPRI_CTL_STABILIZING);
	}
	assert(plan.reasons == CAPRI_CTL_HARDWARE_LOCKOUT);
	assert(plan.source_candidate);
	assert(plan.fcc_ua == 200000 && plan.fv_uv == 4450000);
	assert(plan.usb_icl_ua == 500000);
	++scenarios;

	/* Power charger readiness and AUTO policy are required before the controller
	 * can grant charging. No amount of stable input samples bypasses it.
	 */
	o = nominal;
	o.runtime_charge_enabled = true;
	state = (struct capri_control_state){};
	for (i = 0; i < 3; ++i) {
		plan = capri_control_calculate(&state, &o);
		assert(plan.charging_permitted == (i == 2));
	}
	assert(plan.reasons == 0);
	assert(plan.fcc_ua == 200000 && plan.usb_icl_ua == 500000);
	++scenarios;

	/* Both normal CDP and DCP may use the existing 500mA limit;
	 * unrecognized or Qualcomm high-voltage source codes still fail.
	 */
	o.usb_sdp = false;
	o.usb_dcp = true;
	state = (struct capri_control_state){};
	for (i = 0; i < 3; ++i)
		plan = capri_control_calculate(&state, &o);
	assert(plan.charging_permitted);
	++scenarios;
	o.usb_dcp = false;
	o.usb_cdp = true;
	state = (struct capri_control_state){};
	for (i = 0; i < 3; ++i)
		plan = capri_control_calculate(&state, &o);
	assert(plan.charging_permitted);
	++scenarios;

	o.usb_cdp = false;
	state = (struct capri_control_state){};
	for (i = 0; i < 3; ++i)
		plan = capri_control_calculate(&state, &o);
	assert(!plan.charging_permitted &&
	       (plan.reasons & CAPRI_CTL_SOURCE_UNVERIFIED));
	++scenarios;
	o = nominal;
	o.runtime_charge_enabled = true;
	o.temperature_decic = 405;
	state = (struct capri_control_state){};
	for (i = 0; i < 3; ++i)
		plan = capri_control_calculate(&state, &o);
	assert(!plan.charging_permitted &&
	       (plan.reasons & CAPRI_CTL_TEMP_OUTSIDE));
	++scenarios;
	o = nominal;
	o.runtime_charge_enabled = true;
	o.usb_icl_ua = 1000000;
	state = (struct capri_control_state){};
	for (i = 0; i < 3; ++i)
		plan = capri_control_calculate(&state, &o);
	assert(!plan.charging_permitted &&
	       (plan.reasons & CAPRI_CTL_INPUT_INVALID));
	++scenarios;

	o.usb_online = false;
	plan = capri_control_calculate(&state, &o);
	assert(plan.reasons & CAPRI_CTL_NO_SOURCE);
	assert(!plan.source_candidate && state.stable_samples == 0);
	o = nominal;
	plan = capri_control_calculate(&state, &o);
	assert(plan.reasons & CAPRI_CTL_STABILIZING);
	++scenarios;

	o = nominal; o.usb_sdp = false;
	step_fault("unknown source", o, CAPRI_CTL_SOURCE_UNVERIFIED);
	++scenarios;
	o = nominal; o.aicl_done = false;
	step_fault("AICL not completed", o, CAPRI_CTL_INPUT_INVALID);
	++scenarios;
	o = nominal; o.usb_path_valid = false;
	step_fault("invalid input path", o, CAPRI_CTL_INPUT_INVALID);
	++scenarios;
	o = nominal; o.usb_sample_valid = false;
	step_fault("stale input ADC", o, CAPRI_CTL_INPUT_INVALID);
	++scenarios;
	o = nominal; o.usb_icl_ua = 900000;
	step_fault("USB limit over SDP", o, CAPRI_CTL_INPUT_INVALID);
	++scenarios;
	o = nominal; o.usb_current_ua = 788600;
	step_fault("measured input over effective AICL", o, CAPRI_CTL_INPUT_INVALID);
	++scenarios;
	o = nominal; o.usb_current_ua = -1;
	step_fault("invalid input-current ADC", o, CAPRI_CTL_INPUT_INVALID);
	++scenarios;
	o = nominal; o.usb_voltage_uv = 4300000;
	step_fault("VBUS undervoltage", o, CAPRI_CTL_INPUT_INVALID);
	++scenarios;
	o = nominal; o.usb_voltage_uv = 6500000;
	step_fault("VBUS overvoltage", o, CAPRI_CTL_INPUT_INVALID);
	++scenarios;
	o = nominal; o.battery_present = false;
	step_fault("battery absent", o, CAPRI_CTL_BAD_GAUGE);
	++scenarios;
	o = nominal; o.gauge_valid = false;
	step_fault("QGauge unavailable", o, CAPRI_CTL_BAD_GAUGE);
	++scenarios;
	o = nominal; o.health_good = false;
	step_fault("battery health bad", o, CAPRI_CTL_BAD_GAUGE);
	++scenarios;
	o = nominal; o.battery_voltage_uv = 4450000;
	step_fault("battery at float", o, CAPRI_CTL_HIGH_BATTERY);
	++scenarios;
	o = nominal; o.battery_voltage_uv = 2000000;
	step_fault("battery below safe profile", o, CAPRI_CTL_HIGH_BATTERY);
	++scenarios;

	for (i = -100; i <= 700; ++i) {
		if (i < 150 || i >= 400) {
			o = nominal; o.temperature_decic = i;
			step_fault("non-central temperature", o,
				   CAPRI_CTL_TEMP_OUTSIDE);
			++scenarios;
		}
	}
	o = nominal; o.temperature_decic = 150;
	state = (struct capri_control_state){};
	for (i = 0; i < 3; ++i)
		plan = capri_control_calculate(&state, &o);
	assert(plan.source_candidate && plan.zone == CAPRI_ZONE_NORMAL);
	o.temperature_decic = 400;
	plan = capri_control_calculate(&state, &o);
	assert(!plan.source_candidate && plan.fv_uv == 4200000);
	++scenarios;

	o = nominal; o.session_elapsed_ms = 768ULL * 60 * 1000 + 1;
	step_fault("session timer expired", o, CAPRI_CTL_SESSION_TIMEOUT);
	++scenarios;

	/* A fault is sticky even after unplug/replug; an untrusted USB
	 * source cannot reset a real charger or watchdog fault.
	 */
	o = nominal; o.watchdog_bark = true;
	state = (struct capri_control_state){};
	plan = capri_control_calculate(&state, &o);
	assert(plan.reasons & CAPRI_CTL_WDOG_BARK);
	o = nominal; o.usb_online = false;
	(void)capri_control_calculate(&state, &o);
	o = nominal;
	for (i = 0; i < 4; ++i)
		plan = capri_control_calculate(&state, &o);
	assert(plan.reasons & CAPRI_CTL_WDOG_BARK);
	assert(plan.reasons & CAPRI_CTL_FAULT_LATCHED);
	assert(!plan.charging_permitted && !plan.source_candidate);
	++scenarios;
	o = nominal; o.charger_fault = true;
	state = (struct capri_control_state){};
	plan = capri_control_calculate(&state, &o);
	assert(plan.reasons & CAPRI_CTL_CHARGER_FAULT);
	o = nominal;
	for (i = 0; i < 4; ++i)
		plan = capri_control_calculate(&state, &o);
	assert(plan.reasons & CAPRI_CTL_FAULT_LATCHED);
	assert(!plan.source_candidate);
	++scenarios;

	/* Passive battery samples near float must never count as taper,
	 * even when the synthetic current itself looks within 102mA.
	 */
	o = nominal;
	o.battery_voltage_uv = 4440000;
	o.charge_current_ua = 80000;
	o.charge_current_calibrated = true;
	state = (struct capri_control_state){};
	for (i = 0; i < 6; ++i)
		plan = capri_control_calculate(&state, &o);
	assert(!state.terminated && state.taper_samples == 0);
	++scenarios;

	/* Simulate an *externally verified* charging session to test only
	 * the software termination counter; this never runs on the device.
	 */
	o.charging_active = true;
	for (i = 0; i < 3; ++i)
		plan = capri_control_calculate(&state, &o);
	assert(state.terminated && state.taper_samples == 3);
	assert(plan.reasons & CAPRI_CTL_TERMINATION);
	assert(!plan.source_candidate);
	o.usb_online = false;
	plan = capri_control_calculate(&state, &o);
	assert(!state.terminated);
	++scenarios;

	/* Measured overdraw latches through USB disconnect/reconnect. */
	o = nominal; o.usb_current_ua = 788600;
	state = (struct capri_control_state){};
	plan = capri_control_calculate(&state, &o);
	assert(state.input_fault_latched && (plan.reasons & CAPRI_CTL_INPUT_INVALID));
	o.usb_online = false;
	(void)capri_control_calculate(&state, &o);
	o = nominal;
	for (i = 0; i < 4; ++i)
		plan = capri_control_calculate(&state, &o);
	assert(state.input_fault_latched && (plan.reasons & CAPRI_CTL_FAULT_LATCHED));
	assert(!plan.source_candidate && !plan.charging_permitted);
	++scenarios;

	/* Pure engine fuzz: weird readings must never grant hardware
	 * control, and no candidate may exceed the sensed SDP limit.
	 */
	for (i = 0; i < 50000; ++i) {
		o = nominal;
		o.temperature_decic = (i * 179 % 1200) - 300;
		o.battery_voltage_uv = (i * 43 % 3200) * 1000 + 2200000;
		o.usb_voltage_uv = (i * 71 % 9000) * 1000;
		o.usb_icl_ua = (i * 13 % 90) * 50000;
		o.usb_current_ua = (i * 37 % 700) * 1000;
		o.usb_sdp = i % 3 != 0;
		o.gauge_valid = i % 101 != 0;
		o.charger_fault = i % 127 == 0;
		state = (struct capri_control_state){};
		plan = capri_control_calculate(&state, &o);
		assert(plan.reasons & CAPRI_CTL_HARDWARE_LOCKOUT);
		assert(!plan.charging_permitted);
		if (plan.source_candidate) {
			assert(o.usb_sdp);
			assert(o.usb_icl_ua >= 100000 &&
			       o.usb_icl_ua <= 500000);
			assert(plan.fcc_ua <= 200000);
			assert(plan.usb_icl_ua <= o.usb_icl_ua);
			assert(o.usb_current_ua <= o.usb_icl_ua);
		}
	}
	++scenarios;
	printf("PASS: %u controller scenarios and 50,000 fail-closed fuzz inputs\n",
	       scenarios);
	puts("PASS: source, temperature zones, termination and watchdog latching");
	puts("PASS: Power charging requires enabled driver, AUTO and valid inputs");
	return 0;
}

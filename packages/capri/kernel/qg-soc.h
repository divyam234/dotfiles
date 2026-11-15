/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef CAPRI_QG_SOC_H
#define CAPRI_QG_SOC_H

#include <linux/math64.h>
#include <linux/types.h>

/*
 * Reporting-only, awake-time charge estimate. Units are microamp-milliseconds
 * so sub-microamp-hour changes are not lost at each sample. This does not
 * control the charger, write gauge registers, or persist estimates in SDAM.
 */
#define QG_SOC_UAMS_PER_UAH 3600000LL
#define QG_SOC_MAX_GAP_MS 30000

struct qg_soc {
	s64 full_uams;
	s64 charge_uams;
	s64 last_ms;
	int last_ua;
	bool initialized;
	bool sample_valid;
};

static inline bool qg_soc_seed(struct qg_soc *soc, int full_uah, int capacity)
{
	if (full_uah <= 0 || capacity < 0 || capacity > 100)
		return false;

	soc->full_uams = (s64)full_uah * QG_SOC_UAMS_PER_UAH;
	soc->charge_uams = div64_s64(soc->full_uams * capacity, 100);
	soc->initialized = true;
	soc->sample_valid = false;
	return true;
}

static inline void qg_soc_invalidate_sample(struct qg_soc *soc)
{
	soc->sample_valid = false;
}

static inline void qg_soc_mark_full(struct qg_soc *soc)
{
	if (soc->initialized) {
		soc->charge_uams = soc->full_uams;
		soc->sample_valid = false;
	}
}

static inline void qg_soc_sample(struct qg_soc *soc, s64 now_ms, int current_ua)
{
	s64 elapsed, delta;

	if (!soc->initialized)
		return;

	elapsed = now_ms - soc->last_ms;
	/*
	 * Do not extrapolate through read failures, suspend, scheduling stalls,
	 * backwards timestamps, or a detected charge/discharge transition.
	 */
	if (soc->sample_valid && elapsed > 0 && elapsed <= QG_SOC_MAX_GAP_MS &&
	    !((soc->last_ua < 0 && current_ua > 0) ||
	      (soc->last_ua > 0 && current_ua < 0))) {
		delta = div64_s64(((s64)soc->last_ua + current_ua) * elapsed, 2);
		soc->charge_uams += delta;
		if (soc->charge_uams < 0)
			soc->charge_uams = 0;
		else if (soc->charge_uams > soc->full_uams)
			soc->charge_uams = soc->full_uams;
	}

	soc->last_ms = now_ms;
	soc->last_ua = current_ua;
	soc->sample_valid = true;
}

static inline int qg_soc_capacity(const struct qg_soc *soc)
{
	return div64_s64(soc->charge_uams * 100 + soc->full_uams / 2,
			 soc->full_uams);
}

#endif

/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <limits.h>
#include <stdio.h>

#include "../kernel/qg-soc.h"

static void integrate(struct qg_soc *soc, int current, int samples)
{
	s64 start = soc->sample_valid ? soc->last_ms : 0;
	int i;

	qg_soc_sample(soc, start, current);
	for (i = 1; i <= samples; i++)
		qg_soc_sample(soc, start + i * 10000LL, current);
}

int main(void)
{
	struct qg_soc soc = { 0 };
	s64 charge;

	assert(!qg_soc_seed(&soc, 0, 50));
	assert(!qg_soc_seed(&soc, -1, 50));
	assert(!qg_soc_seed(&soc, 6000000, -1));
	assert(!qg_soc_seed(&soc, 6000000, 101));
	qg_soc_sample(&soc, 10000, 1000000);
	assert(!soc.initialized);

	assert(qg_soc_seed(&soc, 6000000, 50));
	/* 3.6 A for 10 minutes adds 600 mAh: 10% of a 6000 mAh pack. */
	integrate(&soc, 3600000, 60);
	assert(qg_soc_capacity(&soc) == 60);
	qg_soc_invalidate_sample(&soc);
	integrate(&soc, -3600000, 60);
	assert(qg_soc_capacity(&soc) == 50);

	/* Trapezoidal integration, preserving fractions of a microamp-hour. */
	assert(qg_soc_seed(&soc, 6000000, 50));
	charge = soc.charge_uams;
	qg_soc_sample(&soc, 0, 1);
	qg_soc_sample(&soc, 10000, 3);
	assert(soc.charge_uams - charge == 20000);

	charge = soc.charge_uams;
	qg_soc_sample(&soc, 1000000, 3000000);
	assert(soc.charge_uams == charge); /* Long unsampled gap. */
	qg_soc_sample(&soc, 999999, 3000000);
	assert(soc.charge_uams == charge); /* Clock moved backwards. */
	qg_soc_sample(&soc, 999999, 3000000);
	assert(soc.charge_uams == charge); /* Duplicate timestamp. */
	qg_soc_sample(&soc, 1009999, -3000000);
	assert(soc.charge_uams == charge); /* Charger transition. */

	qg_soc_invalidate_sample(&soc); /* Read failure or suspend. */
	qg_soc_sample(&soc, 1019999, -3000000);
	assert(soc.charge_uams == charge);
	qg_soc_sample(&soc, 1029999, -3000000);
	assert(soc.charge_uams == charge - 30000000000LL);

	assert(qg_soc_seed(&soc, 1, 99));
	integrate(&soc, INT_MAX, 1);
	assert(qg_soc_capacity(&soc) == 100);
	qg_soc_invalidate_sample(&soc);
	integrate(&soc, INT_MIN, 1);
	assert(qg_soc_capacity(&soc) == 0);
	qg_soc_mark_full(&soc);
	assert(qg_soc_capacity(&soc) == 100);
	assert(!soc.sample_valid);

	/* A new valid OCV can re-anchor the estimate without carrying a sample. */
	assert(qg_soc_seed(&soc, 6106000, 73));
	assert(qg_soc_capacity(&soc) == 73);
	assert(!soc.sample_valid);
	assert(qg_soc_seed(&soc, INT_MAX, 100));
	assert(qg_soc_capacity(&soc) == 100);

	puts("PASS: QGauge reporting-only SOC arithmetic and sampling boundaries");
	return 0;
}

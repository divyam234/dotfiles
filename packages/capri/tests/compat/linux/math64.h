/* Match signed kernel division's truncation toward zero for host tests. */
#ifndef CAPRI_TEST_LINUX_MATH64_H
#define CAPRI_TEST_LINUX_MATH64_H
#include <linux/types.h>
static inline s64 div64_s64(s64 dividend, s64 divisor)
{
	return dividend / divisor;
}
#endif

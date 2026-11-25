// SPDX-License-Identifier: GPL-2.0-only
/* No hardware access: regular-file blank target and mocked VT ioctls. */
#define ioctl test_ioctl
#define main screen_button_main
#include "screen-button.c"
#undef main
#undef ioctl
#include <assert.h>
#include <stdarg.h>

static int modes[8], mode_count;
static bool fail_graphics;

int test_ioctl(int fd, unsigned long request, ...)
{
	(void)fd;
	assert(request == KDSETMODE);
	va_list args;
	va_start(args, request);
	int mode = va_arg(args, int);
	va_end(args);
	assert(mode_count < 8);
	modes[mode_count++] = mode;
	if (fail_graphics && mode == KD_GRAPHICS) {
		errno = EIO;
		return -1;
	}
	return 0;
}

int main(void)
{
	bool pressed = false;
	struct input_event ev = {.type = EV_KEY, .code = KEY_ASSISTANT, .value = 1};
	assert(key_press(&pressed, &ev));
	assert(!key_press(&pressed, &ev));
	ev.value = 2;
	assert(!key_press(&pressed, &ev));
	ev.value = 0;
	assert(!key_press(&pressed, &ev));
	ev.value = 1;
	assert(key_press(&pressed, &ev));
	ev.code = KEY_POWER;
	ev.value = 0;
	assert(!key_press(&pressed, &ev) && pressed);
	ev.code = KEY_ASSISTANT;
	ev.type = EV_SYN;
	assert(!key_press(&pressed, &ev) && pressed);

	char path[] = "./screen-button-test-XXXXXX";
	int fd = mkstemp(path);
	assert(fd >= 0);
	assert(display(123, KD_TEXT, path, true) == 0);
	assert(mode_count == 1 && modes[0] == KD_GRAPHICS);
	char buf[2];
	assert(pread(fd, buf, 2, 0) == 2 && !memcmp(buf, "4\n", 2));
	assert(display(123, KD_TEXT, path, false) == 0);
	assert(mode_count == 2 && modes[1] == KD_TEXT);
	assert(pread(fd, buf, 2, 0) == 2 && !memcmp(buf, "0\n", 2));
	close(fd);
	unlink(path);

	mode_count = 0;
	assert(display(123, KD_TEXT, "/nonexistent-capri-screen-test/blank", true) == -1);
	assert(mode_count == 2 && modes[0] == KD_GRAPHICS && modes[1] == KD_TEXT);
	mode_count = 0;
	assert(display(123, KD_TEXT, "/nonexistent-capri-screen-test/blank", false) == -1);
	assert(mode_count == 1 && modes[0] == KD_TEXT);
	mode_count = 0;
	fail_graphics = true;
	assert(display(123, KD_TEXT, "/nonexistent-capri-screen-test/blank", true) == -1);
	assert(mode_count == 1);
	puts("PASS: key filtering, VT guard, blank states and failure recovery");
	return 0;
}

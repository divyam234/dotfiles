// SPDX-License-Identifier: GPL-2.0-only
/* Capri text-console display policy. No suspend, storage, or input grab. */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <glob.h>
#include <linux/input.h>
#include <linux/kd.h>
#include <linux/vt.h>
#include <poll.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/ioctl.h>
#include <unistd.h>

static volatile sig_atomic_t stopping;

static bool key_press(bool *pressed, const struct input_event *ev)
{
	if (ev->type != EV_KEY || ev->code != KEY_ASSISTANT)
		return false;
	if (ev->value == 0) {
		*pressed = false;
	} else if (ev->value == 1 && !*pressed) {
		*pressed = true;
		return true;
	}
	return false;
}

static void stop(int sig)
{
	(void)sig;
	stopping = 1;
}

static int set_blank(const char *path, bool off)
{
	int fd = open(path, O_WRONLY | O_CLOEXEC);
	if (fd < 0)
		return -1;
	ssize_t n = write(fd, off ? "4\n" : "0\n", 2);
	int saved = errno;
	if (close(fd) < 0 && n == 2)
		return -1;
	errno = saved;
	if (n != 2) {
		if (n >= 0)
			errno = EIO;
		return -1;
	}
	fprintf(stderr, "screen-button: requested %s\n", off ? "powerdown" : "unblank");
	return 0;
}

static int display(int tty, int original_mode, const char *blank, bool off)
{
	/*
	 * fbdev blanking alone does not change VT ownership. Console activity
	 * can re-enable the fbdev client. While off, inhibit console drawing;
	 * returning to KD_TEXT redraws the original terminal and Buffyboard.
	 */
	if (off && ioctl(tty, KDSETMODE, KD_GRAPHICS) < 0)
		return -1;
	int ret = set_blank(blank, off);
	int saved = errno;
	if ((!off || ret < 0) && ioctl(tty, KDSETMODE, original_mode) < 0) {
		perror("restore VT mode");
		return -1;
	}
	errno = saved;
	return ret;
}

static bool assistant(int fd)
{
	unsigned char keys[KEY_MAX / 8 + 1] = {0};
	return ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(keys)), keys) >= 0 &&
		(keys[KEY_ASSISTANT / 8] & (1u << (KEY_ASSISTANT % 8)));
}

static int find_input(void)
{
	glob_t paths = {0};
	int selected = -1;
	if (glob("/dev/input/event*", 0, NULL, &paths) != 0)
		return -1;
	for (size_t i = 0; i < paths.gl_pathc; i++) {
		int fd = open(paths.gl_pathv[i], O_RDONLY | O_NONBLOCK | O_CLOEXEC);
		if (fd < 0)
			continue;
		if (assistant(fd)) {
			selected = fd;
			fprintf(stderr, "screen-button: using %s\n", paths.gl_pathv[i]);
			break;
		}
		close(fd);
	}
	globfree(&paths);
	return selected;
}

int main(int argc, char **argv)
{
	const char *blank = "/sys/class/graphics/fb0/blank";
	struct sigaction sa = {.sa_handler = stop};
	bool off = false, pressed = false, dropped = false;
	int result = EXIT_FAILURE;

	if (argc != 2 || (strcmp(argv[1], "watch") && strcmp(argv[1], "on"))) {
		fprintf(stderr, "usage: %s watch|on\n", argv[0]);
		return EXIT_FAILURE;
	}
	if (!strcmp(argv[1], "on")) {
		/* Recovery: stop watcher first, then restore the text console. */
		int tty = open("/dev/tty1", O_RDWR | O_CLOEXEC);
		if (tty < 0) {
			perror("recovery tty1");
			return EXIT_FAILURE;
		}
		int ret = display(tty, KD_TEXT, blank, false);
		close(tty);
		if (ret < 0) {
			perror("unblank");
			return EXIT_FAILURE;
		}
		return EXIT_SUCCESS;
	}
	int lock = open("/run/capri-screen-button.lock", O_CREAT | O_RDWR | O_CLOEXEC, 0600);
	if (lock < 0 || flock(lock, LOCK_EX | LOCK_NB) < 0) {
		perror("screen-button lock");
		return EXIT_FAILURE;
	}
	int input = find_input();
	if (input < 0) {
		fprintf(stderr, "screen-button: no KEY_ASSISTANT input; no display changes\n");
		close(lock);
		return EXIT_FAILURE;
	}
	int tty = open("/dev/tty1", O_RDWR | O_CLOEXEC);
	int mode;
	struct vt_stat vt;
	if (tty < 0 || ioctl(tty, KDGETMODE, &mode) < 0 ||
	    ioctl(tty, VT_GETSTATE, &vt) < 0 || vt.v_active != 1 || mode != KD_TEXT) {
		fprintf(stderr, "screen-button: requires active text-mode tty1; refusing display changes\n");
		if (tty >= 0)
			close(tty);
		close(input);
		close(lock);
		return EXIT_FAILURE;
	}
	sigemptyset(&sa.sa_mask);
	if (sigaction(SIGINT, &sa, NULL) || sigaction(SIGTERM, &sa, NULL) ||
	    sigaction(SIGHUP, &sa, NULL)) {
		perror("sigaction");
		goto done;
	}
	/* Start from a known visible state; restore visibility on normal exit. */
	if (display(tty, mode, blank, false) < 0) {
		perror("initial unblank");
		goto done;
	}
	result = EXIT_SUCCESS;
	while (!stopping) {
		struct pollfd pfd = {.fd = input, .events = POLLIN};
		int ready = poll(&pfd, 1, 500);
		if (ready < 0 && errno == EINTR)
			continue;
		if (ready < 0 || (pfd.revents & (POLLERR | POLLHUP | POLLNVAL))) {
			fprintf(stderr, "screen-button: input poll failed\n");
			result = EXIT_FAILURE;
			break;
		}
		if (!ready)
			continue;
		struct input_event ev;
		ssize_t n = read(input, &ev, sizeof(ev));
		if (n < 0 && (errno == EAGAIN || errno == EINTR))
			continue;
		if (n != sizeof(ev)) {
			fprintf(stderr, "screen-button: short/failed input read\n");
			result = EXIT_FAILURE;
			break;
		}
		if (ev.type == EV_SYN && ev.code == SYN_DROPPED) {
			dropped = true;
			pressed = false;
			continue;
		}
		if (dropped) {
			if (ev.type == EV_SYN && ev.code == SYN_REPORT) {
				unsigned char keys[KEY_MAX / 8 + 1] = {0};
				if (ioctl(input, EVIOCGKEY(sizeof(keys)), keys) < 0) {
					result = EXIT_FAILURE;
					break;
				}
				pressed = keys[KEY_ASSISTANT / 8] & (1u << (KEY_ASSISTANT % 8));
				dropped = false;
			}
			continue;
		}
		if (key_press(&pressed, &ev)) {
			if (display(tty, mode, blank, !off) < 0) {
				perror("display toggle");
				result = EXIT_FAILURE;
				break;
			}
			off = !off;
		}
	}
	if (display(tty, mode, blank, false) < 0) {
		perror("restore display");
		result = EXIT_FAILURE;
	}
done:
	close(tty);
	close(input);
	close(lock);
	return result;
}

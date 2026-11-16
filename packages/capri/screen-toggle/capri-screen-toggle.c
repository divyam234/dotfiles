// SPDX-License-Identifier: MIT
// Moto G10 Power: GPIO33 Assistant key -> native MSM DRM DSI pipeline on/off.
// Does not suspend Linux; saves/reapplies native panel brightness across DRM OFF/ON.
// Requires the Capri kernel gpio-keys DTS addition and an active MSM/DSI mode.
#define _POSIX_C_SOURCE 200809L

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#include <xf86drm.h>
#include <xf86drmMode.h>

#define MAX_CARDS 16
#define MAX_INPUTS 64
#define RETRY_SECONDS 5
#define INPUT_KEY_BITS ((KEY_MAX + 8) / 8)

static volatile sig_atomic_t exiting;

struct display {
    int fd;
    uint32_t connector_id;
    uint32_t crtc_id;
    uint32_t active_property_id;
    char card[32];
    bool disabled_by_us;
};

static void on_signal(int signum)
{
    (void)signum;
    exiting = 1;
}


#define BACKLIGHT_BRIGHTNESS "/sys/class/backlight/5e94000.dsi.0/brightness"
#define BACKLIGHT_MAX "/sys/class/backlight/5e94000.dsi.0/max_brightness"
#define SAVED_DIR "/run/capri-screen-toggle"
#define SAVED_BRIGHTNESS SAVED_DIR "/brightness"

/* Always target Capri's native DSI panel, never unrelated LEDs or devices. */
static int read_uint_file(const char *path, unsigned *number)
{
    FILE *file = fopen(path, "r");
    if (!file)
        return -1;
    int result = fscanf(file, "%u", number) == 1 ? 0 : -1;
    fclose(file);
    return result;
}

static int remember_brightness(void)
{
    unsigned current, maximum;
    if (read_uint_file(BACKLIGHT_BRIGHTNESS, &current) < 0 ||
        read_uint_file(BACKLIGHT_MAX, &maximum) < 0 ||
        maximum == 0 || current > maximum) {
        fprintf(stderr, "capri-screen-toggle: cannot save panel brightness; refusing OFF\n");
        return -1;
    }
    if (mkdir(SAVED_DIR, 0700) < 0 && errno != EEXIST) {
        perror("capri-screen-toggle: create runtime directory");
        return -1;
    }
    FILE *file = fopen(SAVED_BRIGHTNESS ".tmp", "w");
    if (!file)
        return -1;
    int failed = fprintf(file, "%u\n", current) < 0 ||
                 fflush(file) != 0 || fsync(fileno(file)) != 0;
    if (fclose(file) != 0)
        failed = 1;
    if (failed || rename(SAVED_BRIGHTNESS ".tmp", SAVED_BRIGHTNESS) < 0) {
        perror("capri-screen-toggle: save brightness");
        unlink(SAVED_BRIGHTNESS ".tmp");
        return -1;
    }
    fprintf(stderr, "capri-screen-toggle: saved panel brightness %u/%u\n",
            current, maximum);
    return 0;
}

static int restore_brightness(void)
{
    unsigned current, maximum;
    if (read_uint_file(BACKLIGHT_MAX, &maximum) < 0 || !maximum) {
        fprintf(stderr, "capri-screen-toggle: backlight max unavailable\n");
        return -1;
    }

    /* The saved brightness takes priority. --on without an earlier --off
     * can still resend the existing sysfs brightness to undo the panel's
     * hardcoded 0x000a brightness from the initialization sequence. */
    bool from_snapshot = read_uint_file(SAVED_BRIGHTNESS, &current) == 0;
    if (!from_snapshot && read_uint_file(BACKLIGHT_BRIGHTNESS, &current) < 0)
        return -1;
    if (current > maximum) {
        fprintf(stderr, "capri-screen-toggle: saved brightness out of range\n");
        return -1;
    }

    // The kernel reissues DCS 0x51 even when the sysfs value is unchanged.
    int fd = open(BACKLIGHT_BRIGHTNESS, O_WRONLY | O_CLOEXEC);
    if (fd < 0) {
        perror("capri-screen-toggle: open panel brightness");
        return -1;
    }
    char buffer[32];
    int length = snprintf(buffer, sizeof(buffer), "%u\n", current);
    ssize_t written = write(fd, buffer, (size_t)length);
    int saved_errno = errno;
    close(fd);
    if (written != length) {
        errno = written < 0 ? saved_errno : EIO;
        perror("capri-screen-toggle: reapply panel brightness");
        return -1;
    }
    if (from_snapshot)
        unlink(SAVED_BRIGHTNESS); // Do not override later user brightness changes.
    fprintf(stderr, "capri-screen-toggle: restored panel brightness %u/%u\n",
            current, maximum);
    return 0;
}

static int query_active(const struct display *display, uint64_t *active)
{
    drmModeObjectProperties *props = drmModeObjectGetProperties(
        display->fd, display->crtc_id, DRM_MODE_OBJECT_CRTC);
    if (!props)
        return -1;

    int result = -1;
    for (uint32_t i = 0; i < props->count_props; ++i) {
        if (props->props[i] == display->active_property_id) {
            *active = props->prop_values[i];
            result = 0;
            break;
        }
    }
    drmModeFreeObjectProperties(props);
    return result;
}

static int set_active(struct display *display, bool on)
{
    if (!on && remember_brightness() < 0)
        return -1; // Never go dark unless brightness can be restored.
    drmModeAtomicReq *req = drmModeAtomicAlloc();
    if (!req) {
        fprintf(stderr, "capri-screen-toggle: cannot allocate DRM request\n");
        return -1;
    }
    if (drmModeAtomicAddProperty(req, display->crtc_id,
                                 display->active_property_id, on ? 1 : 0) < 0) {
        fprintf(stderr, "capri-screen-toggle: cannot add CRTC ACTIVE property\n");
        drmModeAtomicFree(req);
        return -1;
    }

    // Only ACTIVE changes: mode, planes, connector and framebuffer stay assigned.
    // MSM's atomic KMS implementation handles DSI/panel enable and disable.
    int result = drmModeAtomicCommit(display->fd, req,
                                     DRM_MODE_ATOMIC_ALLOW_MODESET, NULL);
    int saved_errno = errno;
    drmModeAtomicFree(req);
    if (result < 0) {
        fprintf(stderr, "capri-screen-toggle: CRTC ACTIVE=%u failed: %s\n",
                (unsigned)on, strerror(saved_errno));
        return -1;
    }
    fprintf(stderr, "capri-screen-toggle: native DSI display %s\n",
            on ? "ON" : "OFF");
    if (on) {
        // Panel preparation sends brightness 0x000a (very dim).
        // Reapply the saved value after DRM has prepared the panel.
        struct timespec settle = { .tv_sec = 0, .tv_nsec = 100000000 };
        nanosleep(&settle, NULL);
        if (restore_brightness() < 0)
            return -1;
    }
    return 0;
}

static int get_active_property(int fd, uint32_t crtc_id,
                               uint32_t *prop_id, uint64_t *value)
{
    drmModeObjectProperties *props = drmModeObjectGetProperties(
        fd, crtc_id, DRM_MODE_OBJECT_CRTC);
    if (!props)
        return -1;

    int result = -1;
    for (uint32_t i = 0; i < props->count_props; ++i) {
        drmModePropertyRes *prop = drmModeGetProperty(fd, props->props[i]);
        if (prop && !strcmp(prop->name, "ACTIVE")) {
            *prop_id = props->props[i];
            *value = props->prop_values[i];
            result = 0;
        }
        if (prop)
            drmModeFreeProperty(prop);
        if (result == 0)
            break;
    }
    drmModeFreeObjectProperties(props);
    return result;
}

static int find_dsi_crtc(int fd, struct display *display, uint64_t *active)
{
    drmModeRes *resources = drmModeGetResources(fd);
    if (!resources)
        return -1;

    int result = -1;
    for (int i = 0; i < resources->count_connectors; ++i) {
        drmModeConnector *conn = drmModeGetConnector(fd, resources->connectors[i]);
        if (!conn)
            continue;

        if (conn->connector_type != DRM_MODE_CONNECTOR_DSI ||
            !conn->encoder_id ||
            conn->connection == DRM_MODE_DISCONNECTED) {
            drmModeFreeConnector(conn);
            continue;
        }

        drmModeEncoder *encoder = drmModeGetEncoder(fd, conn->encoder_id);
        if (encoder && encoder->crtc_id) {
            drmModeCrtc *crtc = drmModeGetCrtc(fd, encoder->crtc_id);
            if (crtc && crtc->mode_valid &&
                get_active_property(fd, encoder->crtc_id,
                                    &display->active_property_id, active) == 0) {
                display->connector_id = conn->connector_id;
                display->crtc_id = encoder->crtc_id;
                result = 0;
            }
            if (crtc)
                drmModeFreeCrtc(crtc);
        }
        if (encoder)
            drmModeFreeEncoder(encoder);
        drmModeFreeConnector(conn);
        if (result == 0)
            break;
    }
    drmModeFreeResources(resources);
    return result;
}

static int open_native_display(struct display *display, uint64_t *active)
{
    memset(display, 0, sizeof(*display));
    display->fd = -1;

    for (int i = 0; i < MAX_CARDS; ++i) {
        char card[32];
        snprintf(card, sizeof(card), "/dev/dri/card%d", i);
        int fd = open(card, O_RDWR | O_CLOEXEC);
        if (fd < 0)
            continue;

        drmVersionPtr version = drmGetVersion(fd);
        bool msm = version && version->name && !strcmp(version->name, "msm");
        if (version)
            drmFreeVersion(version);
        if (!msm) {
            close(fd);
            continue;  // Refuse simpledrm: it cannot control the actual panel.
        }

        if (drmSetClientCap(fd, DRM_CLIENT_CAP_ATOMIC, 1) < 0) {
            fprintf(stderr, "capri-screen-toggle: %s lacks atomic KMS: %s\n",
                    card, strerror(errno));
            close(fd);
            continue;
        }

        display->fd = fd;
        if (find_dsi_crtc(fd, display, active) < 0) {
            close(fd);
            display->fd = -1;
            continue;  // Avoid disabling an unconfigured or unrelated output.
        }

        // Do not disrupt another userspace compositor's DRM master.
        if (drmSetMaster(fd) < 0) {
            fprintf(stderr, "capri-screen-toggle: %s DRM master unavailable: %s\n",
                    card, strerror(errno));
            close(fd);
            display->fd = -1;
            continue;
        }

        snprintf(display->card, sizeof(display->card), "%s", card);
        return 0;
    }
    return -1;
}

static bool assistant_supported(int fd)
{
    unsigned char keys[INPUT_KEY_BITS] = { 0 };
    char name[128] = { 0 };
    if (ioctl(fd, EVIOCGNAME(sizeof(name)), name) < 0 ||
        strcmp(name, "gpio-keys") != 0)
        return false;
    if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(keys)), keys) < 0)
        return false;
    return (keys[KEY_ASSISTANT / 8] & (1u << (KEY_ASSISTANT % 8))) != 0;
}

static int open_assistant_input(void)
{
    for (int i = 0; i < MAX_INPUTS; ++i) {
        char path[32];
        snprintf(path, sizeof(path), "/dev/input/event%d", i);
        int fd = open(path, O_RDONLY | O_CLOEXEC | O_NONBLOCK);
        if (fd < 0)
            continue;
        if (assistant_supported(fd)) {
            fprintf(stderr, "capri-screen-toggle: Assistant key on %s\n", path);
            return fd;
        }
        close(fd);
    }
    return -1;
}

static void restore_if_needed(struct display *display)
{
    if (display->disabled_by_us) {
        if (set_active(display, true) == 0)
            display->disabled_by_us = false;
    }
}

static int watch_buttons(struct display *display)
{
    int input = -1;
    bool reported_missing = false;
    struct timespec last_press = { 0, 0 };

    while (!exiting) {
        if (input < 0) {
            input = open_assistant_input();
            if (input < 0) {
                if (!reported_missing) {
                    fprintf(stderr,
                            "capri-screen-toggle: waiting for GPIO33 KEY_ASSISTANT "
                            "(requires updated Capri kernel)\n");
                    reported_missing = true;
                }
                sleep(RETRY_SECONDS);
                continue;
            }
            reported_missing = false;
        }

        struct pollfd pfd = { .fd = input, .events = POLLIN };
        int result = poll(&pfd, 1, 1000);
        if (result < 0) {
            if (errno == EINTR)
                continue;
            perror("capri-screen-toggle: poll");
            restore_if_needed(display);
            close(input);
            input = -1;
            continue;
        }
        if (result == 0)
            continue;
        if (pfd.revents & (POLLHUP | POLLNVAL | POLLERR)) {
            // Recover illumination if the wake button disappears unexpectedly.
            restore_if_needed(display);
            close(input);
            input = -1;
            continue;
        }

        struct input_event events[16];
        ssize_t size = read(input, events, sizeof(events));
        if (size < 0 && (errno == EAGAIN || errno == EINTR))
            continue;
        if (size <= 0 || (size_t)size % sizeof(events[0]) != 0) {
            restore_if_needed(display);
            close(input);
            input = -1;
            continue;
        }

        for (size_t i = 0; i < (size_t)size / sizeof(events[0]); ++i) {
            if (events[i].type != EV_KEY || events[i].code != KEY_ASSISTANT ||
                events[i].value != 1)
                continue;  // Ignore release and auto-repeat.

            struct timespec now;
            clock_gettime(CLOCK_MONOTONIC, &now);
            long elapsed_ms = (now.tv_sec - last_press.tv_sec) * 1000L +
                              (now.tv_nsec - last_press.tv_nsec) / 1000000L;
            if (last_press.tv_sec && elapsed_ms >= 0 && elapsed_ms < 250)
                continue;
            last_press = now;

            uint64_t active;
            if (query_active(display, &active) < 0) {
                fprintf(stderr, "capri-screen-toggle: CRTC ACTIVE unavailable\n");
                continue;
            }
            bool want_on = active == 0;
            if (set_active(display, want_on) == 0)
                display->disabled_by_us = !want_on;
        }
    }

    if (input >= 0)
        close(input);
    restore_if_needed(display);
    return 0;
}

int main(int argc, char **argv)
{
    enum { DAEMON, CHECK, FORCE_ON, FORCE_OFF, MANUAL_CYCLE } mode = DAEMON;

    if (argc == 2 && strcmp(argv[1], "--check") == 0)
        mode = CHECK;
    else if (argc == 2 && strcmp(argv[1], "--on") == 0)
        mode = FORCE_ON;
    else if (argc == 2 && strcmp(argv[1], "--off") == 0)
        mode = FORCE_OFF;
    else if (argc == 2 && strcmp(argv[1], "--cycle") == 0)
        mode = MANUAL_CYCLE;
    else if (argc != 1) {
        fprintf(stderr, "Usage: %s [--check|--off|--on|--cycle]\n", argv[0]);
        return 2;
    }

    if (mode == DAEMON || mode == MANUAL_CYCLE) {
        struct sigaction action = { .sa_handler = on_signal };
        sigemptyset(&action.sa_mask);
        sigaction(SIGINT, &action, NULL);
        sigaction(SIGTERM, &action, NULL);
        sigaction(SIGHUP, &action, NULL);
    }

    struct display display;
    uint64_t active = 0;
    if (open_native_display(&display, &active) < 0) {
        fprintf(stderr, "capri-screen-toggle: native MSM DSI KMS with a "
                        "configured CRTC is unavailable; not changing screen\n");
        return 1;
    }

    fprintf(stderr, "capri-screen-toggle: %s DSI connector=%u CRTC=%u ACTIVE=%llu\n",
            display.card, display.connector_id, display.crtc_id,
            (unsigned long long)active);

    if (mode == CHECK) {
        int button = open_assistant_input();
        fprintf(stderr, "capri-screen-toggle: GPIO33 Assistant key %s\n",
                button >= 0 ? "present" : "not exposed by running kernel");
        if (button >= 0)
            close(button);
    } else if (mode == FORCE_ON) {
        // Reapply brightness even if the CRTC is already active.
        // This repairs a display left dim by an older --on invocation.
        if ((!active && set_active(&display, true) < 0) ||
            (active && restore_brightness() < 0)) {
            drmDropMaster(display.fd);
            close(display.fd);
            return 1;
        }
    } else if (mode == FORCE_OFF) {
        // An explicit --off leaves the display off until a separate --on.
        // Do not set disabled_by_us: that would trigger automatic restoration.
        if (active && set_active(&display, false) < 0) {
            drmDropMaster(display.fd);
            close(display.fd);
            return 1;
        }
    } else if (mode == MANUAL_CYCLE) {
        // Manual demonstration: leave all other services running and guarantee
        // an ON attempt from the same process after 5 seconds or a signal.
        if (active != 1) {
            fprintf(stderr, "capri-screen-toggle: screen was not active; refusing cycle\n");
            drmDropMaster(display.fd);
            close(display.fd);
            return 1;
        }
        if (set_active(&display, false) < 0) {
            drmDropMaster(display.fd);
            close(display.fd);
            return 1;
        }
        display.disabled_by_us = true;
        for (int seconds = 0; seconds < 5 && !exiting; ++seconds)
            sleep(1);
        restore_if_needed(&display);
        uint64_t final_active = 0;
        if (display.disabled_by_us || query_active(&display, &final_active) < 0 ||
            final_active != 1) {
            fprintf(stderr, "capri-screen-toggle: FAILED to confirm display ON\n");
            drmDropMaster(display.fd);
            close(display.fd);
            return 1;
        }
        fprintf(stderr, "capri-screen-toggle: verified CRTC ACTIVE=1 after cycle\n");
    } else {
        // Starting the service itself never switches the display off.
        watch_buttons(&display);
    }

    drmDropMaster(display.fd);
    close(display.fd);
    return 0;
}

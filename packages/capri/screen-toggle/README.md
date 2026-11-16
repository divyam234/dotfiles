# Capri Power: Assistant button display power toggle

This targets the Moto G10 Power (XT2127-4) running the existing 50 MHz
Linux/NixOS configuration. **It is unrelated to the failed HS200/HS400 tests.**

## Hardware support

Motorola's Bengal/Capri vendor Device Tree identifies the separate Assistant
button on TLMM GPIO 33, active low. The additional
`0006-kernel-capri-assistant-button.patch` exposes it through the existing
`gpio-keys` input device as `KEY_ASSISTANT` (code `0x247`). Power and volume
keys are unchanged.

The native display is Qualcomm MSM DRM, not merely the early `simpledrm`
framebuffer. On the running working kernel, read-only probing confirmed:

- `/dev/dri/card1` is the MSM DRM device.
- Connector `36` is DSI, CRTC `49` has `ACTIVE=1`.
- `/proc/fb` reports `msmdrmfb`.
- The DJN NT36525B panel and Linux backlight were initialized.
- The Assistant key is **not present** until the new DTB/kernel boots.

## Behavior

A root-owned systemd service monitors `KEY_ASSISTANT` presses and uses the
atomic DRM CRTC `ACTIVE` property. It preserves the assigned mode, framebuffer,
planes, and connectors while requesting real display-pipeline shutdown and
restoration. The existing Capri panel driver handles DSI Display OFF / Sleep IN
and panel initialization on the corresponding DRM transitions.

This does **not** set brightness to zero, disable Wi-Fi, suspend NixOS, or
modify eMMC speed. The panel driver currently leaves some PMI632 display-bias
power under firmware management; this is not complete regulator power-off.

The service acts only on the native `msm` DRM driver with an assigned DSI
connector and CRTC. It refuses `simpledrm` or an unconfigured display. Button
releases/repeats are ignored; a short debounce is applied. Unexpected input
device loss, normal service shutdown, and systemd `ExecStopPost` attempt to
restore the display to ON.

## Deployment

Build or switch the Capri NixOS configuration through the normal extlinux
workflow. Keep the previous known-working generation as fallback. The kernel
patch requires rebuilding the kernel/DTB. **Do not flash boot partitions or
use an experimental HS200/HS400 kernel.**

After booting the new generation:

```sh
sudo capri-screen-toggle --check
systemctl status capri-screen-toggle
journalctl -u capri-screen-toggle -b --no-pager
```

The check should show a native MSM/DSI CRTC and the Assistant key on a
`/dev/input/event*` device. Press the physical Assistant key once to switch the
panel off, and once again to switch it on.

Recovery over SSH (does not require the display to be visible):

```sh
sudo systemctl stop capri-screen-toggle  # ExecStopPost attempts display ON
sudo capri-screen-toggle --on            # independent display-on command
sudo systemctl start capri-screen-toggle
```

`--check` is read-only with respect to display power. Keep SSH operational
during the first real button test. If DSI reinitialization fails, reboot into
the previous working NixOS generation.

## Validation before deployment

- NixOS Capri `systemd.services.capri-screen-toggle` evaluates successfully.
- C program builds with `libdrm` and `-Werror`.
- Read-only `--check` was run as root on the current Capri NixOS system.
- No physical screen-off/on cycle has yet been attempted.

{ pkgs, ... }:
let
  screenToggle = pkgs.callPackage ../../packages/capri/screen-toggle { };
in
{
  # GPIO33 is the Moto G10 Power's dedicated Assistant button.
  # The corresponding gpio-keys KEY_ASSISTANT is added in kernel patch 0006.
  # Unlike brightness=0, setting the MSM DRM CRTC ACTIVE=0 requests a real
  # DSI pipeline shutdown and the panel's Display OFF + Sleep IN sequence.
  environment.systemPackages = [ screenToggle ];

  systemd.services.capri-screen-toggle = {
    description = "Capri Assistant button: native display power toggle";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-trigger.service" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${screenToggle}/bin/capri-screen-toggle";
      # Best-effort rescue when stopping/restarting the service, even if it
      # crashes while the panel is asleep. Can also be run manually over SSH.
      ExecStopPost = "-${screenToggle}/bin/capri-screen-toggle --on";
      # Keep the previous brightness across manual OFF and ON invocations.
      RuntimeDirectory = "capri-screen-toggle";
      RuntimeDirectoryMode = "0700";
      RuntimeDirectoryPreserve = "yes";
      Restart = "on-failure";
      RestartSec = "10s";
      TimeoutStopSec = "10s";
      User = "root";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      # Only this panel's brightness sysfs node may be written by the service.
      # ProtectKernelTunables would make that backlight control read-only.
      ReadWritePaths = [ "/sys/class/backlight/5e94000.dsi.0/brightness" ];
      ProtectControlGroups = true;
      # Do not set PrivateDevices: the service needs /dev/dri and /dev/input.
    };
  };
}

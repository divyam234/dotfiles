{ pkgs, ... }:
let
  screenButton = pkgs.callPackage ../../packages/capri/screen-button { };
in
{
  environment.systemPackages = [ screenButton ];

  systemd.services.capri-screen-button = {
    description = "Capri assistant-button screen toggle";
    wantedBy = [ "multi-user.target" ];
    wants = [ "capri-buffyboard.service" ];
    after = [
      "systemd-udev-trigger.service"
      "systemd-vconsole-setup.service"
      "getty@tty1.service"
      "capri-buffyboard.service"
    ];
    unitConfig = {
      ConditionPathExists = "/sys/class/graphics/fb0/blank";
      StartLimitIntervalSec = 60;
      StartLimitBurst = 5;
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${screenButton}/bin/capri-screen-button watch";
      # Also restore the text console after a crash/forced termination.
      ExecStopPost = "${screenButton}/bin/capri-screen-button on";
      Restart = "on-failure";
      RestartSec = "3s";
      TimeoutStopSec = "5s";
    };
  };
}

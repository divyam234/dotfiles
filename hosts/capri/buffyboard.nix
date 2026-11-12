{ pkgs, ... }:
let
  buffyboard = pkgs.callPackage ../../packages/capri/buffyboard { };
in
{
  # Buffyboard writes to the framebuffer and injects keys through uinput.
  # Both uinput and evdev are built into the pinned Capri kernel, not modules.
  boot.kernelModules = [ "novatek-nt36525b-capri" ];

  # Match the legible console font that is used in the RAMUI prototype.
  console.font = "ter-128n";
  console.packages = [ pkgs.terminus_font ];

  environment.systemPackages = [ buffyboard ];

  systemd.services.capri-buffyboard = {
    description = "Capri touchscreen keyboard (Buffyboard)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "systemd-udev-trigger.service"
      "systemd-vconsole-setup.service"
    ];
    serviceConfig = {
      ExecStart = "${buffyboard}/bin/buffyboard";
      Restart = "always";
      RestartSec = "2s";
    };
  };

  # Do not autologin as root or bypass the existing NixOS login policy.
  # This unit runs on the real root filesystem, not the early initrd.
}

{ ideapad }:
let
  userHome = ideapad.home-manager.users.bhunter;
  niriConfig = userHome.xdg.configFile."niri/config.kdl".text;
  contains = needle: builtins.replaceStrings [ needle ] [ "" ] niriConfig != niriConfig;
in
assert ideapad.facter.report.hardware.system.form_factor == "laptop";
assert ideapad.facter.detected.graphics.amd.enable;
assert ideapad.fileSystems."/".fsType == "ext4";
assert ideapad.fileSystems."/mnt/drive".fsType == "ext4";
assert !(ideapad.services.btrfs.autoScrub.enable or false);
assert ideapad.hardware.graphics.enable;
assert ideapad.hardware.graphics.enable32Bit;
assert ideapad.boot.kernelPackages.kernel.pname == "linux-cachyos-latest-x86_64-v3";
assert builtins.hasAttr "niri/config.kdl" userHome.xdg.configFile;
assert !(builtins.hasAttr "gh-auth" userHome.systemd.user.services);
assert contains ''output "eDP-1" {'';
assert contains "scale 1.250000";
assert userHome.sops.age.keyFile == "/var/lib/sops-nix/key.txt";
assert builtins.elem "tailscaled.service" ideapad.systemd.services.tailscale-autoconnect.after;
assert ideapad.systemd.services.tailscale-autoconnect.serviceConfig.Restart == "on-failure";
true

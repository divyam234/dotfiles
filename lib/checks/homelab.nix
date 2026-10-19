{ homelab }:
let
  userHome = homelab.home-manager.users.bhunter;
in
assert homelab.services.pipewire.enable;
assert homelab.services.pipewire.pulse.enable;
assert homelab.services.pipewire.alsa.enable;
assert homelab.security.rtkit.enable;
assert builtins.elem "audio" homelab.users.users.bhunter.extraGroups;
assert userHome.services.librespot.enable;
assert userHome.services.librespot.settings.name == "homelab";
assert userHome.services.librespot.settings.backend == "pulseaudio";
assert userHome.services.librespot.settings.cache == "/mnt/drive/librespot/cache";
assert userHome.services.librespot.settings.zeroconf-port == 24879;
assert builtins.elem 24879 homelab.networking.firewall.allowedTCPPorts;
assert builtins.elem 5353 homelab.networking.firewall.allowedUDPPorts;
assert builtins.elem "/mnt/drive"
  homelab.systemd.services.systemd-tmpfiles-setup.unitConfig.RequiresMountsFor;
assert homelab.users.users.bhunter.linger;
assert !(builtins.hasAttr "rclone-serve-webdav" userHome.systemd.user.services);
true

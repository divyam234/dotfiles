{ homelab }:
let
  userHome = homelab.home-manager.users.bhunter;
in
assert homelab.services.pipewire.enable;
assert homelab.services.pipewire.pulse.enable;
assert homelab.services.pipewire.alsa.enable;
assert homelab.security.rtkit.enable;
assert builtins.elem "audio" homelab.users.users.bhunter.extraGroups;
assert homelab.users.users.bhunter.linger;
assert !(builtins.hasAttr "rclone-serve-webdav" userHome.systemd.user.services);
true

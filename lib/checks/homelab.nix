{ homelab, lib }:
let
  stashHost = "stash.bhunter.tech";
  caddyfile = homelab.environment.etc."caddy/Caddyfile".text;
  dnsManifest = builtins.fromJSON (
    builtins.readFile homelab.environment.etc."cloudflare-dns/manifest.json".source
  );
  userHome = homelab.home-manager.users.bhunter;
in
assert lib.hasInfix stashHost caddyfile;
assert builtins.elem {
  name = stashHost;
  proxied = false;
  target = "tailscale-ipv4";
  type = "A";
} dnsManifest.records;
assert homelab.virtualisation.quadlet.containers.stash.containerConfig.exec == "serve";
assert builtins.hasAttr "ghcr-auth" homelab.systemd.services;
assert builtins.hasAttr "ghcr-auth" userHome.systemd.user.services;
assert builtins.elem "ghcr-auth.service"
  homelab.virtualisation.quadlet.containers.stash.unitConfig.Requires;
assert builtins.elem "tailscale-autoconnect.service"
  homelab.virtualisation.quadlet.containers.stash.unitConfig.After;
assert builtins.elem "/mnt/external/caddy-cache:/var/cache/caddy"
  homelab.virtualisation.quadlet.containers.caddy.containerConfig.volumes;
assert builtins.elem "/mnt/external/caddy-cache"
  homelab.virtualisation.quadlet.containers.caddy.unitConfig.RequiresMountsFor;
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
assert lib.hasInfix "cache_dir /var/cache/caddy/vips" caddyfile;
assert !lib.hasInfix "varc" caddyfile;
true

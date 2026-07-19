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
assert builtins.elem "/var/cache/caddy:/var/cache/caddy"
  homelab.virtualisation.quadlet.containers.caddy.containerConfig.volumes;
assert lib.hasInfix "cache_dir /var/cache/caddy/vips" caddyfile;
assert lib.hasInfix "cache_dir /var/cache/caddy/varc" caddyfile;
assert lib.hasInfix "varc stash:8080" caddyfile;
true

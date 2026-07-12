{ homelab, lib }:
let
  domain = homelab.networking.domain;
  caddyfile = homelab.environment.etc."caddy/Caddyfile".text;
  dnsManifest = builtins.fromJSON (
    builtins.readFile homelab.environment.etc."cloudflare-dns/manifest.json".source
  );
  webdav = homelab.systemd.services.rclone-webdav;
in
assert lib.hasInfix "media.${domain}" caddyfile;
assert builtins.elem {
  name = "media.${domain}";
  proxied = false;
  target = "tailscale-ipv4";
  type = "A";
} dnsManifest.records;
assert builtins.elem "/mnt/drive/rclone" webdav.serviceConfig.ReadWritePaths;
assert builtins.elem 9000 homelab.networking.firewall.interfaces."br-svc".allowedTCPPorts;
true

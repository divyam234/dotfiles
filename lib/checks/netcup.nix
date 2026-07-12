{ lib, netcup }:
let
  hostName = netcup.networking.hostName;
  domain = netcup.networking.domain;
  caddyfile = netcup.environment.etc."caddy/Caddyfile".text;
  dnsManifest = builtins.fromJSON (
    builtins.readFile netcup.environment.etc."cloudflare-dns/manifest.json".source
  );
  userName = builtins.head (builtins.attrNames netcup.home-manager.users);
in
assert domain != null;
assert builtins.hasAttr userName netcup.home-manager.users;
assert builtins.hasAttr hostName netcup.services.restic.backups;
assert builtins.elem 53 netcup.networking.firewall.interfaces."br-svc".allowedUDPPorts;
assert lib.hasInfix "git.${domain}" caddyfile;
assert lib.hasInfix "vault.${domain}" caddyfile;
assert builtins.elem {
  name = "git.${domain}";
  proxied = false;
  target = "tailscale-ipv4";
  type = "A";
} dnsManifest.records;
assert builtins.elem {
  name = "vault.${domain}";
  proxied = true;
  target = "public-ipv4";
  type = "A";
} dnsManifest.records;
assert builtins.elem {
  name = "codeforge.${domain}";
  proxied = true;
  target = "public-ipv4";
  type = "A";
} dnsManifest.records;
true

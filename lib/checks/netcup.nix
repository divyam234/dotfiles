{ lib, netcup }:
let
  hostName = netcup.networking.hostName;
  caddyfile = netcup.environment.etc."caddy/Caddyfile".text;
  dnsManifest = builtins.fromJSON (
    builtins.readFile netcup.environment.etc."cloudflare-dns/manifest.json".source
  );
  domain = dnsManifest.zone;
  userName = builtins.head (builtins.attrNames netcup.home-manager.users);
  userHome = netcup.home-manager.users.${userName};
in
assert builtins.hasAttr userName netcup.home-manager.users;
assert builtins.hasAttr hostName netcup.services.restic.backups;
assert netcup.virtualisation.quadlet.containers.stash-worker.containerConfig.exec == "worker";
assert builtins.hasAttr "ghcr-auth" netcup.systemd.services;
assert builtins.hasAttr "ghcr-auth" userHome.systemd.user.services;
assert builtins.elem "ghcr-auth.service"
  netcup.virtualisation.quadlet.containers.stash-worker.unitConfig.Requires;
assert builtins.elem "/home/bhunter/downloads:/downloads"
  netcup.virtualisation.quadlet.containers.stash-worker.containerConfig.volumes;
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

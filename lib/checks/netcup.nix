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
  containerIngress = netcup.networking.nftables.tables.container-ingress.content;
in
assert builtins.hasAttr userName netcup.home-manager.users;
assert builtins.hasAttr hostName netcup.services.restic.backups;
assert builtins.hasAttr "ghcr-auth" netcup.systemd.services;
assert builtins.hasAttr "ghcr-auth" userHome.systemd.user.services;
assert builtins.elem "/var/cache/caddy:/var/cache/caddy"
  netcup.virtualisation.quadlet.containers.caddy.containerConfig.volumes;
assert builtins.elem 53 netcup.networking.firewall.interfaces."br-svc".allowedUDPPorts;
assert netcup.networking.nftables.enable;
assert
  netcup.virtualisation.quadlet.containers.gluetun.containerConfig.publishPorts == [
    "3128:3128"
    "1081:1081"
  ];
assert
  netcup.virtualisation.quadlet.containers.pgdog.containerConfig.publishPorts == [ "6432:6432" ];
assert netcup.virtualisation.quadlet.containers.postgres.containerConfig.publishPorts == [ ];
assert lib.hasInfix ''iifname "eth0" ct status dnat tcp dport { 80, 443 } accept'' containerIngress;
assert lib.hasInfix ''iifname "eth0" ct status dnat udp dport 443 accept'' containerIngress;
assert lib.hasInfix ''iifname "eth0" ct status dnat drop'' containerIngress;
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

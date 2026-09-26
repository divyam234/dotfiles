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
assert builtins.hasAttr "opencode/cli.json" userHome.xdg.configFile;
assert (builtins.fromJSON userHome.xdg.configFile."opencode/cli.json".text).theme.name == "stylix";
assert builtins.hasAttr "opencode" userHome.systemd.user.services;
assert builtins.hasAttr "ida-mcp" userHome.systemd.user.services;
assert
  userHome.programs.opencode.settings.mcp.servers.ida == {
    type = "remote";
    url = "https://ida.${domain}/mcp";
    disabled = true;
  };
assert builtins.elem 8745 netcup.networking.firewall.interfaces."br-svc".allowedTCPPorts;
assert !(builtins.elem 8745 netcup.networking.firewall.allowedTCPPorts);
assert lib.hasInfix "ida.${domain}" caddyfile;
assert builtins.hasAttr "openchamber" userHome.systemd.user.services;
assert
  userHome.systemd.user.services.openchamber.Service.EnvironmentFile == [
    "%h/.config/opencode/opencode.env"
    "%h/.config/opencode/opencode-server.env"
  ];
assert
  userHome.systemd.user.services.opencode.Service.EnvironmentFile
  == userHome.systemd.user.services.openchamber.Service.EnvironmentFile;
assert builtins.hasAttr "opencode.env" userHome.sops.templates;
assert builtins.hasAttr "opencode-server.env" userHome.sops.templates;
assert builtins.hasAttr "ghcr-auth" userHome.systemd.user.services;
assert !(builtins.hasAttr "codeforge" netcup.systemd.services);
assert builtins.hasAttr "codeforge" userHome.systemd.user.services;
assert !(userHome.systemd.user.services.codeforge.Service ? NoNewPrivileges);
assert builtins.hasAttr "codeforge.env" userHome.sops.templates;
assert builtins.elem "/var/cache/caddy:/var/cache/caddy"
  netcup.virtualisation.quadlet.containers.caddy.containerConfig.volumes;
assert builtins.elem 53 netcup.networking.firewall.interfaces."br-svc".allowedUDPPorts;
assert netcup.networking.nftables.enable;
assert
  netcup.virtualisation.quadlet.containers.gluetun.containerConfig.publishPorts == [
    "3128:3128"
    "3129:3129"
    "1081:1081"
  ];
assert
  netcup.virtualisation.quadlet.containers.pgdog.containerConfig.publishPorts == [ "6432:6432" ];
assert netcup.virtualisation.quadlet.containers.postgres.containerConfig.publishPorts == [ ];
assert lib.hasInfix ''iifname "eth0" ct status dnat tcp dport { 80, 443 } accept'' containerIngress;
assert lib.hasInfix ''iifname "eth0" ct status dnat udp dport 443 accept'' containerIngress;
assert lib.hasInfix ''iifname "eth0" ct status dnat drop'' containerIngress;
assert lib.hasInfix "git.${domain}" caddyfile;
assert lib.hasInfix "gemini.${domain}" caddyfile;
assert lib.hasInfix "vault.${domain}" caddyfile;
assert lib.hasInfix "auth.${domain}" caddyfile;
assert lib.hasInfix "stash.${domain}" caddyfile;
assert lib.hasInfix "reverse_proxy gateauth:8080" caddyfile;
assert lib.hasInfix "rewrite /api/verify?application=default-app" caddyfile;
assert lib.hasInfix
  "redir https://auth.${domain}/login?redirect=https://{http.request.host}{http.request.uri} 302"
  caddyfile;
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
assert builtins.elem {
  name = "auth.${domain}";
  proxied = true;
  target = "public-ipv4";
  type = "A";
} dnsManifest.records;
assert builtins.elem {
  name = "stash.${domain}";
  proxied = true;
  target = "public-ipv4";
  type = "A";
} dnsManifest.records;
true

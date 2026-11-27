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
assert !(builtins.hasAttr "opencode/tui.json" userHome.xdg.configFile);
assert builtins.hasAttr "opencode/cli.json" userHome.xdg.configFile;
assert builtins.hasAttr "opencode/themes/stylix.json" userHome.xdg.configFile;
assert builtins.hasAttr "opencode" userHome.systemd.user.services;
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
assert !(builtins.hasAttr "imgresize" netcup.virtualisation.quadlet.containers);
assert !(builtins.hasAttr "mtproxy" netcup.virtualisation.quadlet.containers);
assert
  netcup.virtualisation.quadlet.containers.gateauth.containerConfig.environments.SEED_DEFAULT_APPLICATION
  == "false";
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
assert !(lib.hasInfix "HTTPPROXY=" netcup.sops.templates."gluetun.env".content);
assert !(lib.hasInfix "HTTPPROXY_LISTENING_ADDRESS=" netcup.sops.templates."gluetun.env".content);
assert
  netcup.virtualisation.quadlet.containers.gluetun.containerConfig.environments.FIREWALL_INPUT_PORTS
  == "3128";
assert netcup.virtualisation.quadlet.containers.postgres.containerConfig.publishPorts == [ ];
assert lib.hasInfix ''iifname "eth0" ct status dnat tcp dport { 80, 443 } accept'' containerIngress;
assert lib.hasInfix ''iifname "eth0" ct status dnat udp dport 443 accept'' containerIngress;
assert lib.hasInfix ''iifname "eth0" ct status dnat drop'' containerIngress;
assert
  netcup.virtualisation.quadlet.containers.camofox-browser.containerConfig.image
  == "ghcr.io/tgdrive/camofox-browser:latest";
assert
  netcup.virtualisation.quadlet.containers.camofox-browser.containerConfig.publishPorts
  == [ "9377:9377" ];
assert builtins.elem 9377 netcup.networking.firewall.interfaces.tailscale0.allowedTCPPorts;
assert builtins.elem 9377 netcup.networking.firewall.interfaces."br-svc".allowedTCPPorts;
assert lib.hasInfix "git.${domain}" caddyfile;
assert !(netcup.virtualisation.quadlet.containers ? gemini-fastapi);
assert !(lib.hasInfix "gemini.${domain}" caddyfile);
assert lib.hasInfix "vault.${domain}" caddyfile;
assert lib.hasInfix "auth.${domain}" caddyfile;
assert lib.hasInfix "streamweave.${domain}" caddyfile;
assert lib.hasInfix "reverse_proxy streamweave:8080" caddyfile;
assert builtins.elem {
  name = "streamweave.${domain}";
  proxied = true;
  target = "public-ipv4";
  type = "A";
} dnsManifest.records;
assert lib.hasInfix "reverse_proxy gateauth:8080" caddyfile;
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
  name = "auth.${domain}";
  proxied = true;
  target = "public-ipv4";
  type = "A";
} dnsManifest.records;
true

{ lib, netcup }:
let
  hostName = netcup.networking.hostName;
  domain = netcup.networking.domain;
  caddyfile = netcup.environment.etc."caddy/Caddyfile".text;
  userName = builtins.head (builtins.attrNames netcup.home-manager.users);
in
assert domain != null;
assert builtins.hasAttr userName netcup.home-manager.users;
assert builtins.hasAttr hostName netcup.services.restic.backups;
assert builtins.elem 53 netcup.networking.firewall.interfaces."br-svc".allowedUDPPorts;
assert lib.hasInfix "git.${domain}" caddyfile;
assert lib.hasInfix "vault.${domain}" caddyfile;
true

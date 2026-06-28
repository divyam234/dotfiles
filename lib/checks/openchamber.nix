{ lib, netcup }:
let
  userName = builtins.head (builtins.attrNames netcup.home-manager.users);
  userHome = netcup.home-manager.users.${userName};
  openchamber = userHome.systemd.user.services.openchamber;
  opencode = userHome.systemd.user.services.opencode;
  firewall = netcup.networking.firewall.interfaces."br-svc";
  caddyfile = netcup.environment.etc."caddy/Caddyfile".text;
  domain = netcup.networking.domain;
in
assert netcup.users.users.${userName}.linger == true;
assert builtins.elem 39173 firewall.allowedTCPPorts;
assert builtins.hasAttr "openchamber" userHome.systemd.user.services;
assert builtins.hasAttr "opencode" userHome.systemd.user.services;
assert lib.hasInfix "--port 39173" (lib.concatStringsSep " " openchamber.Service.ExecStart);
assert lib.hasInfix "--port 4095" (lib.concatStringsSep " " opencode.Service.ExecStart);
assert lib.hasInfix "ai.${domain}" caddyfile;
true

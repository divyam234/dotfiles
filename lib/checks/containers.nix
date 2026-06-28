{ lib, netcup }:
let
  expected = [
    "adguard-cli"
    "caddy"
    "camofox-browser"
    "codeforge-mcp"
    "databasus"
    "forgejo"
    "gluetun"
    "hermes"
    "pgdog"
    "postgres"
    "redis"
    "siyuan"
    "vaultwarden"
  ];
  names = builtins.attrNames netcup.virtualisation.quadlet.containers;
  missing = lib.filter (name: !(builtins.elem name names)) expected;
  userName = builtins.head (builtins.attrNames netcup.home-manager.users);
  user = netcup.users.users.${userName};
  volumes = netcup.virtualisation.quadlet.containers.codeforge-mcp.containerConfig.volumes;
  expectedWorkspace = "${user.home}/repos/github:/workspace";
  expectedAgent = "/run/user/${toString user.uid}/gnupg/S.gpg-agent.ssh:/ssh-agent";
in
assert missing == [ ];
assert builtins.hasAttr "svc" netcup.virtualisation.quadlet.networks;
assert builtins.elem expectedWorkspace volumes;
assert builtins.elem expectedAgent volumes;
true

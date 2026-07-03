{ lib, netcup }:
let
  expected = [
    "adguard-cli"
    "caddy"
    "camofox-browser"
    "databasus"
    "forgejo"
    "gluetun"
    "gproxy"
    "hermes"
    "pgdog"
    "postgres"
    "redis"
    "siyuan"
    "vaultwarden"
  ];
  names = builtins.attrNames netcup.virtualisation.quadlet.containers;
  missing = lib.filter (name: !(builtins.elem name names)) expected;
in
assert missing == [ ];
assert builtins.hasAttr "svc" netcup.virtualisation.quadlet.networks;
true

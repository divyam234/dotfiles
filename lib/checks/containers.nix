{
  homelab,
  lib,
  netcup,
}:
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
  hasUpdateServices =
    host:
    builtins.hasAttr "container-update-webhook" host.systemd.services
    && builtins.hasAttr "podman-auto-update" host.systemd.services
    && builtins.hasAttr "podman-auto-update" host.systemd.timers;
in
assert missing == [ ];
assert builtins.hasAttr "svc" netcup.virtualisation.quadlet.networks;
assert hasUpdateServices netcup;
assert hasUpdateServices homelab;
assert netcup.systemd.services.container-update-webhook.serviceConfig.IPAddressDeny == "any";
assert homelab.systemd.services.container-update-webhook.serviceConfig.IPAddressDeny == "any";
assert netcup.systemd.timers.podman-auto-update.timerConfig.Persistent;
assert homelab.systemd.timers.podman-auto-update.timerConfig.Persistent;
assert !(netcup.systemd.services.podman-auto-update.serviceConfig ? ExecStart);
assert !(homelab.systemd.services.podman-auto-update.serviceConfig ? ExecStart);
assert !(builtins.elem 9080 netcup.networking.firewall.allowedTCPPorts);
assert !(builtins.elem 9080 homelab.networking.firewall.allowedTCPPorts);
true

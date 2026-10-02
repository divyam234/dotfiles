{
  homelab,
  ideapad,
  laptop,
  lib,
  netcup,
}:
let
  expected = [
    "adguard-cli"
    "caddy"
    "camofox-browser"
    "forgejo"
    "gateauth"
    "gemini-fastapi"
    "gluetun"
    "gproxy"
    "pgdog"
    "postgres"
    "redis"
    "siyuan"
    "streamweave"
    "vaultwarden"
  ];
  names = builtins.attrNames netcup.virtualisation.quadlet.containers;
  missing = lib.filter (name: !(builtins.elem name names)) expected;
  hasUpdateServices =
    host:
    builtins.hasAttr "container-update-webhook" host.systemd.services
    && builtins.hasAttr "podman-auto-update" host.systemd.services
    && builtins.hasAttr "podman-auto-update" host.systemd.timers;
  hasContainerPolicy =
    host:
    lib.all (
      container:
      container.autoStart
      && container.containerConfig.autoUpdate == "registry"
      && container.containerConfig.stopTimeout == 60
      && container.serviceConfig.Restart == "always"
      && container.serviceConfig.RestartSec == "10s"
      && container.serviceConfig.NoNewPrivileges
      && container.serviceConfig.TimeoutStopSec == "70s"
    ) (builtins.attrValues host.virtualisation.quadlet.containers);
  hasCleanupPolicy =
    host:
    let
      timer = host.systemd.timers.podman-cleanup.timerConfig;
      home = host.home-manager.users.bhunter;
      userTimer = home.systemd.user.timers.podman-cleanup.Timer;
    in
    !host.virtualisation.podman.autoPrune.enable
    && host.users.users.bhunter.linger
    && host.systemd.services.podman-cleanup.serviceConfig.Type == "oneshot"
    && timer.OnCalendar == "Sun *-*-* 04:00:00"
    && timer.RandomizedDelaySec == "45m"
    && timer.AccuracySec == "1m"
    && !timer.Persistent
    && home.systemd.user.services.podman-cleanup.Service.Type == "oneshot"
    && userTimer.OnCalendar == timer.OnCalendar
    && userTimer.RandomizedDelaySec == timer.RandomizedDelaySec
    && userTimer.AccuracySec == timer.AccuracySec
    && !userTimer.Persistent;
in
assert missing == [ ];
assert builtins.hasAttr "svc" netcup.virtualisation.quadlet.networks;
assert hasUpdateServices netcup;
assert hasUpdateServices homelab;
assert hasContainerPolicy netcup;
assert hasContainerPolicy laptop;
assert hasContainerPolicy ideapad;
assert hasContainerPolicy homelab;
assert hasCleanupPolicy netcup;
assert hasCleanupPolicy homelab;
assert
  netcup.virtualisation.quadlet.containers.streamweave.containerConfig.image
  == "ghcr.io/divyam234/streamweave:latest";
assert netcup.virtualisation.quadlet.containers.streamweave.containerConfig.publishPorts == [ ];
assert builtins.elem "postgres-provision.service"
  netcup.virtualisation.quadlet.containers.streamweave.unitConfig.Requires;
assert builtins.elem netcup.virtualisation.quadlet.containers.pgdog.ref
  netcup.virtualisation.quadlet.containers.streamweave.unitConfig.Requires;
assert netcup.systemd.services.container-update-webhook.serviceConfig.IPAddressDeny == "any";
assert homelab.systemd.services.container-update-webhook.serviceConfig.IPAddressDeny == "any";
assert netcup.systemd.timers.podman-auto-update.timerConfig.Persistent;
assert homelab.systemd.timers.podman-auto-update.timerConfig.Persistent;
assert !(netcup.systemd.services.podman-auto-update.serviceConfig ? ExecStart);
assert !(homelab.systemd.services.podman-auto-update.serviceConfig ? ExecStart);
assert !(builtins.elem 9080 netcup.networking.firewall.allowedTCPPorts);
assert !(builtins.elem 9080 homelab.networking.firewall.allowedTCPPorts);
assert
  netcup.virtualisation.quadlet.containers.camofox-browser.containerConfig.publishPorts == [
    "9377:9377"
  ];
assert
  netcup.virtualisation.quadlet.containers.camofox-browser.containerConfig.environments.CAMOFOX_BIND_HOST
  == "0.0.0.0";
assert
  netcup.virtualisation.quadlet.containers.camofox-browser.containerConfig.environments.ENABLE_VNC
  == "1";
assert
  netcup.virtualisation.quadlet.containers.adguard-cli.containerConfig.networks
  == [ "container:gluetun" ];
true

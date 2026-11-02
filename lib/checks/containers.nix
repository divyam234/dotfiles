{
  homelab,
  ideapad,
  laptop,
  lib,
  netcup,
  netcupSystem,
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
    builtins.hasAttr "podman-auto-update" host.systemd.services
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
    && !host.systemd.services.podman-prune.enable
    && !host.systemd.timers.podman-prune.enable
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
  secretEnvironmentFixture =
    extra:
    (netcupSystem.extendModules {
      modules = [
        {
          virtualisation.quadlet.containers.secret-env-check = {
            containerConfig.image = "example.invalid/check:latest";
            secretEnvironment.TOKEN = "fixture-token";
          };
        }
        extra
      ];
    }).config;
  validFixture = secretEnvironmentFixture {
    virtualisation.quadlet.containers.secret-env-check.containerConfig.environments.PUBLIC = "visible";
    sops.templates."secret-env-check.env".path = lib.mkForce "/run/custom-secret-env";
    sops.useSystemdActivation = true;
  };
  duplicateFixture = secretEnvironmentFixture {
    virtualisation.quadlet.containers.secret-env-check.containerConfig.environments.TOKEN = "duplicate";
  };
  invalidNameFixture = secretEnvironmentFixture {
    virtualisation.quadlet.containers.secret-env-check.secretEnvironment."BAD=NAME" = "value";
  };
  multilineFixture = secretEnvironmentFixture {
    virtualisation.quadlet.containers.secret-env-check.secretEnvironment.TOKEN =
      lib.mkForce "first\nsecond";
  };
  emptyFixture = secretEnvironmentFixture {
    virtualisation.quadlet.containers.secret-env-check.secretEnvironment = lib.mkForce { };
  };
  hasSecretEnvironmentPolicy =
    host:
    lib.all (
      name:
      let
        container = host.virtualisation.quadlet.containers.${name};
        template = host.sops.templates."${name}.env";
      in
      container.secretEnvironment == { }
      || (
        template.mode == "0400"
        && template.uid == 0
        && template.gid == 0
        && builtins.elem "${name}.service" template.restartUnits
        && builtins.elem template.path container.containerConfig.environmentFiles
      )
    ) (builtins.attrNames host.virtualisation.quadlet.containers);
in
assert lib.all hasSecretEnvironmentPolicy [
  homelab
  ideapad
  laptop
  netcup
];
assert builtins.elem "/run/custom-secret-env"
  validFixture.virtualisation.quadlet.containers.secret-env-check.containerConfig.environmentFiles;
assert validFixture.sops.templates."secret-env-check.env".content == "TOKEN=fixture-token\n";
assert !(builtins.all (entry: entry.assertion) duplicateFixture.assertions);
assert !(builtins.all (entry: entry.assertion) invalidNameFixture.assertions);
assert !(builtins.tryEval multilineFixture.sops.templates."secret-env-check.env".content).success;
assert !(builtins.hasAttr "secret-env-check.env" emptyFixture.sops.templates);
assert builtins.elem "sops-install-secrets.service"
  validFixture.virtualisation.quadlet.containers.secret-env-check.unitConfig.After;
assert builtins.elem "sops-install-secrets.service"
  validFixture.virtualisation.quadlet.containers.secret-env-check.unitConfig.Requires;
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
assert netcup.systemd.timers.podman-auto-update.timerConfig.Persistent;
assert homelab.systemd.timers.podman-auto-update.timerConfig.Persistent;
assert !(netcup.systemd.services.podman-auto-update.serviceConfig ? ExecStart);
assert !(homelab.systemd.services.podman-auto-update.serviceConfig ? ExecStart);
assert
  netcup.virtualisation.quadlet.containers.camofox-browser.containerConfig.publishPorts == [
    "9377:9377"
    "5900:5901"
  ];
assert
  netcup.virtualisation.quadlet.containers.camofox-browser.containerConfig.environments.CAMOFOX_BIND_HOST
  == "0.0.0.0";
assert
  netcup.virtualisation.quadlet.containers.camofox-browser.containerConfig.environments.ENABLE_VNC
  == "1";
assert
  netcup.virtualisation.quadlet.containers.camofox-vnc-bridge.containerConfig.networks
  == [ "container:camofox-browser" ];
assert
  netcup.virtualisation.quadlet.containers.camofox-vnc-bridge.unitConfig.Requires
  == [ "camofox-browser.service" ];
assert
  netcup.virtualisation.quadlet.containers.camofox-vnc-bridge.containerConfig.exec == [
    "TCP-LISTEN:5901,fork,reuseaddr"
    "TCP:127.0.0.1:5900"
  ];
assert
  netcup.virtualisation.quadlet.containers.adguard-cli.containerConfig.networks
  == [ "container:gluetun" ];
true

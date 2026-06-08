{ den, lib, ... }:
let
  roleAspects = {
    workstation = [
      den.aspects.common
      den.aspects.users
      den.aspects.security
      den.aspects.sops
      den.aspects.desktop
    ];

    minimal = [
      den.aspects.common
      den.aspects.users
      den.aspects.security
      den.aspects.sops
      den.aspects.development
      den.aspects.firewall
      den.aspects.fail2ban
    ];
  };

  featureAspects = {
    btrfs = den.aspects.btrfs;
    containers = den.aspects.oci-base;
    development = den.aspects.development;
    firewall = den.aspects.firewall;
    fail2ban = den.aspects.fail2ban;
    gaming = den.aspects.gaming;
    tailscale = den.aspects.tailscale;
  };

  serviceAspects = {
    adguard = den.aspects.adguard;
    caddy = den.aspects.caddy;
    camofox = den.aspects.camofox;
    databasus = den.aspects.databasus;
    forgejo = den.aspects.forgejo;
    gluetun = den.aspects.gluetun;
    hermes = den.aspects.hermes;
    pgdog = den.aspects.pgdog;
    postgres = den.aspects.postgres;
    redis = den.aspects.redis;
    restic = den.aspects.restic;
    siyuan = den.aspects.siyuan;
    vaultwarden = den.aspects.vaultwarden;
  };

  resolveNames =
    kind: registry: names:
    map (name: registry.${name} or (throw "Unknown host ${kind}: ${name}")) names;

  enabledServices =
    services: lib.attrNames (lib.filterAttrs (_name: service: service.enable) services);

  selectedAspects =
    host:
    roleAspects.${host.role}
    ++ resolveNames "feature" featureAspects host.features
    ++ resolveNames "service" serviceAspects (enabledServices host.services);
in
{
  den.schema.host.includes = [
    (
      { host, ... }:
      let
        aspects = selectedAspects host;
      in
      {
        includes = aspects;

        # Host-selected aspects should configure both the host class and the
        # users/homes attached to that host. Den does not forward a host
        # aspect's homeManager class to users automatically; this host-to-user
        # provide keeps the inventory-driven feature selection as the single
        # source of truth for NixOS and Home Manager config.
        provides.to-users = { ... }: {
          includes = aspects;
        };
      }
    )
  ];
}

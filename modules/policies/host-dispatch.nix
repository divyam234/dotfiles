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

    server = [
      den.aspects.common
      den.aspects.users
      den.aspects.security
      den.aspects.sops
      den.aspects.server
      den.aspects.firewall
      den.aspects.fail2ban
    ];
  };

  featureAspects = {
    btrfs = den.aspects.btrfs;
    containers = den.aspects.oci-base;
    development = den.aspects.development;
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
in
{
  den.schema.host.includes = [
    (
      { host, ... }:
      {
        includes =
          roleAspects.${host.role}
          ++ resolveNames "feature" featureAspects host.features
          ++ resolveNames "service" serviceAspects host.services;
      }
    )
  ];
}

{ den, ... }:
{
  den.aspects.netcup-services = {
    includes = [
      den.aspects.adguard
      den.aspects.caddy
      den.aspects.camofox
      den.aspects.databasus
      den.aspects.forgejo
      den.aspects.gluetun
      den.aspects.hermes
      den.aspects.pgdog
      den.aspects.postgres
      den.aspects.redis
      den.aspects.restic
      den.aspects.siyuan
      den.aspects.vaultwarden
    ];
  };
}

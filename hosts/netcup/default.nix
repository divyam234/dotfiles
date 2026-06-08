{ den, ... }:
{
  den.aspects.netcup = {
    includes = [
      den.aspects.common
      den.aspects.server

      den.aspects.sops
      den.aspects.security
      den.aspects.users
      den.aspects.firewall
      den.aspects.tailscale
      den.aspects.fail2ban

      den.aspects.caddy
      den.aspects.postgres
      den.aspects.redis
      den.aspects.pgdog
      den.aspects.databasus
      den.aspects.forgejo
      den.aspects.vaultwarden

      den.aspects.gluetun
      den.aspects.adguard

      den.aspects.camofox
      den.aspects.hermes
      den.aspects.siyuan

      den.aspects.restic
    ];

    nixos =
      { ... }:
      {
        imports = [
          ./hardware-configuration.nix
          ./networking.nix
        ];

        system.stateVersion = "25.11";
      };
  };
}

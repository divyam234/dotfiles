{ den, ... }:
{
  den.aspects.netcup = {
    includes = [
      den.aspects.common
      den.aspects.server

      den.aspects.boot
      den.aspects.sops
      den.aspects.security
      den.aspects.users
      den.aspects.firewall
      den.aspects.tailscale
      den.aspects.fail2ban

      den.aspects.oci-base
      den.aspects.container-network
      den.aspects.container-secrets
      den.aspects.caddy-container
      den.aspects.postgres
      den.aspects.valkey
      den.aspects.forgejo
      den.aspects.atuin
      den.aspects.atticd
      den.aspects.vaultwarden
      den.aspects.uptime-kuma
      den.aspects.gotify

      den.aspects.restic
    ];

    nixos = { ... }: {
      imports = [
        ./hardware-configuration.nix
        ./networking.nix
      ];

      networking.hostName = "netcup";
      system.stateVersion = "25.11";
    };
  };
}

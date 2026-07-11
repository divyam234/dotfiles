{ den, ... }:
{
  den.aspects.netcup = {
    includes = [
      den.aspects.common
      den.aspects.sops
      den.aspects.security-base
      den.aspects.server
      den.aspects.tailscale
      den.aspects.integrated-home-manager

      # Shared platform aspects are selected once. Den includes are compositional,
      # so repeating them through every leaf service duplicates quirk producers.
      den.aspects.oci-service
      den.aspects.requires-domain
      den.aspects.requires-secrets
      den.aspects.ai

      den.aspects.adguard
      den.aspects.caddy
      den.aspects.camofox
      den.aspects.codeforge
      den.aspects.databasus
      den.aspects.forgejo
      den.aspects.gluetun
      den.aspects.gproxy
      den.aspects.hermes
      den.aspects.openchamber
      den.aspects.pgdog
      den.aspects.postgres
      den.aspects.redis
      den.aspects.restic
      den.aspects.siyuan
      den.aspects.vaultwarden
    ];

    nixos =
      { host, ... }:
      {
        imports = [
          ./hardware-configuration.nix
          ./boot.nix
          ./disko.nix
          ./networking.nix
        ];

        services.qemuGuest.enable = true;
        networking.domain = host.domain;
        system.stateVersion = "26.05";
      };
  };
}

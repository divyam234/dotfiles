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
      { pkgs, ... }:
      {
        imports = [
          ./hardware-configuration.nix
          ./boot.nix
          ./disko.nix
          ./networking.nix
        ];
        boot.kernelPackages = pkgs.linuxPackages_latest;
        services.qemuGuest.enable = true;
        system.stateVersion = "26.05";
      };
  };
}

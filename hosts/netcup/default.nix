{ den, inputs, ... }:
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
      den.aspects.cloudflare-dns
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
          inputs.nixos-facter-modules.nixosModules.facter
          ./disko.nix
          ./networking.nix
        ];
        boot.kernelParams = [ "console=ttyS0" ];
        boot.loader = {
          grub = {
            enable = true;
            devices = [ "nodev" ];
            efiSupport = true;
            efiInstallAsRemovable = true;
          };

          efi.canTouchEfiVariables = false;
          timeout = 3;
        };
        boot.kernelPackages = pkgs.linuxPackages_latest;
        facter.reportPath = ./facter.json;
        services.qemuGuest.enable = true;
        system.stateVersion = "26.05";
      };
  };
}

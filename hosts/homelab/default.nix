{ den, ... }:
{
  den.aspects.homelab = {
    includes = [
      den.aspects.common
      den.aspects.sops
      den.aspects.boot-policy
      den.aspects.facter
      den.aspects.security-base
      den.aspects.server
      den.aspects.librespot
      den.aspects.tailscale
      den.aspects.integrated-home-manager
      den.aspects.oci-service
      den.aspects.requires-domain
      den.aspects.requires-secrets
      den.aspects.ghcr-auth

      den.aspects.caddy
      den.aspects.cloudflare-dns
    ];

    nixos =
      { ... }:
      {
        imports = [
          ./disko.nix
          ./networking.nix
        ];
        hardware.graphics.enable = true;
        fileSystems."/mnt/drive" = {
          device = "/dev/disk/by-id/ata-ST500LT012-1DG142_WBY3EXQ5-part1";
          fsType = "ext4";
          options = [
            "nofail"
            "x-systemd.automount"
            "noatime"
          ];
        };
        fileSystems."/mnt/external" = {
          device = "/dev/disk/by-id/usb-Samsung_M3_Portable_97EF7DF80600006F-0:0-part1";
          fsType = "ext4";
          options = [
            "nofail"
            "x-systemd.automount"
            "noatime"
          ];
        };
        facter.reportPath = ./facter.json;
        system.stateVersion = "26.05";
      };
  };
}

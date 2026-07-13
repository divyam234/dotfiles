{ den, inputs, ... }:
{
  flake-file.inputs.nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

  den.aspects.homelab = {
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

      den.aspects.caddy
      den.aspects.cloudflare-dns
      den.aspects.rclone-webdav
    ];

    nixos =
      { pkgs, ... }:
      {
        imports = [
          inputs.nixos-facter-modules.nixosModules.facter
          ./disko.nix
          ./networking.nix
        ];
        boot.loader = {
          grub = {
            enable = true;
            configurationLimit = 3;
            devices = [ "nodev" ];
            efiSupport = true;
            efiInstallAsRemovable = true;
          };
          efi.canTouchEfiVariables = false;
          timeout = 3;
        };
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
        facter.reportPath = ./facter.json;
        system.stateVersion = "26.05";
      };
  };
}

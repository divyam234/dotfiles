{ den, ... }:
{
  den.aspects.netcup = {
    includes = [
      den.aspects.infra-host

      den.aspects.adguard
      den.aspects.camofox
      den.aspects.forgejo
      den.aspects.gateauth
      den.aspects.gluetun
      den.aspects.gost
      den.aspects.gproxy
      den.aspects.openchamber
      den.aspects.pgdog
      den.aspects.postgres
      den.aspects.redis
      den.aspects.rclone-webdav
      den.aspects.restic
      den.aspects.siyuan
      den.aspects.streamweave
      den.aspects.teldrive
      den.aspects.vaultwarden
    ];

    nixos =
      { ... }:
      {
        imports = [
          ./disko.nix
          ./networking.nix
        ];
        boot = {
          kernelParams = [ "console=ttyS0" ];
          loader = {
            grub.efiInstallAsRemovable = true;
            efi.canTouchEfiVariables = false;
          };
        };
        facter.reportPath = ./facter.json;
        services.qemuGuest.enable = true;
        system.stateVersion = "26.05";
      };
  };
}

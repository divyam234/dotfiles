{ den, ... }:
{
  den.aspects.netcup = {
    includes = [
      den.aspects.infra-host
      den.aspects.ai

      den.aspects.adguard
      den.aspects.codeforge
      den.aspects.forgejo
      den.aspects.gluetun
      den.aspects.gproxy
      den.aspects.openchamber
      den.aspects.mtproxy
      den.aspects.pgdog
      den.aspects.postgres
      den.aspects.redis
      den.aspects.restic
      den.aspects.siyuan
      den.aspects.stash-worker
      den.aspects.stash
      den.aspects.teldrive
      den.aspects.vaultwarden
    ];

    nixos =
      { pkgs, ... }:
      {
        imports = [
          ./disko.nix
          ./networking.nix
        ];
        boot = {
          kernelPackages = pkgs.linuxPackages_latest;
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

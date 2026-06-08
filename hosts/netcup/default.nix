{ den, ... }:
{
  den.aspects.netcup = {
    nixos =
      { host, pkgs, ... }:
      {
        imports = [
          ./hardware-configuration.nix
        ];

        boot = {
          loader = {
            systemd-boot.enable = false;
            grub = {
              enable = true;
              device = "nodev";
              efiSupport = true;
              efiInstallAsRemovable = true;
            };
          };
          kernelPackages = pkgs.linuxPackages_latest;
        };
        networking.domain = host.domain;
        boot.kernelParams = [ "console=ttyS0" ];
        system.stateVersion = "25.11";
      };
  };
}

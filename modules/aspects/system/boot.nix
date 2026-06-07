
{ den, ... }:
{
  den.aspects.boot = {
    nixos = { lib, pkgs, ... }: {
      boot = {
        loader = {
          systemd-boot.enable = lib.mkDefault true;
          efi.canTouchEfiVariables = lib.mkDefault true;
          timeout = lib.mkDefault 3;
        };
        kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
      };
    };
  };
}

{ den, ... }:
{
  den.aspects.boot-policy.nixos = { lib, ... }: {
    boot.loader = {
      grub = {
        enable = true;
        configurationLimit = 3;
        devices = [ "nodev" ];
        efiSupport = true;
      };
      efi = {
        canTouchEfiVariables = lib.mkDefault true;
        efiSysMountPoint = lib.mkDefault "/boot";
      };
      timeout = 3;
    };
  };
}

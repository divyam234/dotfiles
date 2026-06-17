_:

{
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
}

{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];

  nix.settings = {
    substituters = lib.mkAfter [ "https://attic.xuyh0120.win/lantian" ];
    trusted-public-keys = lib.mkAfter [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-lts-x86_64-v3;
  };
}

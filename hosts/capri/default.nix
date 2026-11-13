{ den, lib, ... }:
{
  den.aspects.capri = {
    includes = [
      # Same NixOS base as netcup, without its container infrastructure.
      den.aspects.base
      den.aspects.server
      den.aspects.home-manager-policy
      den.aspects.teldrive-native
    ];

    nixos = {
      imports = [
        ./buffyboard.nix
        ./hardware.nix
        ./image.nix
        ./modem-nv.nix
        ./usb-ecm.nix
        ./usb-ssh.nix
      ];
      system.stateVersion = "26.05";
      services.teldrive.settings.http.address = lib.mkForce "0.0.0.0:8090";
      services.teldrive.user = "root";
      services.teldrive.group = "root";
    };
  };
}

{ den, ... }:
{
  den.aspects.capri = {
    # Minimal first-boot rootfs; add services later via this flake.
    includes = [ den.aspects.capri-minimal ];

    nixos = {
      imports = [
        ./buffyboard.nix
        ./hardware.nix
        ./image.nix
        ./modem-nv.nix
        ./usb-ecm.nix
      ];
      system.stateVersion = "26.05";
    };
  };
}

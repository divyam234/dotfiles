{ den, ... }:
{
  den.aspects.homepc = {
    includes = [
      den.aspects.common
      den.aspects.desktop
      den.aspects.gaming

      den.aspects.boot
      den.aspects.btrfs
      den.aspects.sops
      den.aspects.security
      den.aspects.users

      den.aspects.kde
      den.aspects.niri
      den.aspects.dms
      den.aspects.matugen
      den.aspects.stylix
      den.aspects.fonts
      den.aspects.portals
      den.aspects.desktop-apps
      den.aspects.ghostty

      den.aspects.oci-base
      den.aspects.container-network
      den.aspects.tailscale
      den.aspects.ollama
      den.aspects.open-webui
    ];

    nixos = { ... }: {
      imports = [
        ./hardware-configuration.nix
        ./disko.nix
      ];

      networking.hostName = "homepc";
      system.stateVersion = "25.11";
    };
  };
}

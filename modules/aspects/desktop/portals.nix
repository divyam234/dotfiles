{ den, ... }:
{
  den.aspects.portals = {
    nixos = { pkgs, ... }: {
      # Niri/DMS session portals. KDE apps are used, but KDE/Plasma is not
      # the desktop environment, so do not use the KDE portal as the default.
      xdg.portal = {
        enable = true;
        xdgOpenUsePortal = true;
        config.common.default = [ "gnome" "gtk" ];
        extraPortals = [
          pkgs.xdg-desktop-portal-gnome
          pkgs.xdg-desktop-portal-gtk
        ];
      };
    };
  };
}

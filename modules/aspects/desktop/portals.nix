{ den, ... }:
{
  den.aspects.portals = {
    nixos =
      { pkgs, ... }:
      {
        xdg.portal = {
          enable = true;
          xdgOpenUsePortal = true;
          config = {
            niri = {
              "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
              "org.freedesktop.impl.portal.Access" = [ "gtk" ];
              "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
              "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
            };
          };
          extraPortals = [
            pkgs.xdg-desktop-portal-gtk
          ];
        };
      };
  };
}

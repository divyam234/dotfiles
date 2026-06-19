{ den, ... }:
{
  den.aspects.portals = {
    nixos =
      { pkgs, ... }:
      {
        # Niri follows the upstream GNOME/GTK portal routing. This provides
        # file pickers, screenshots, screencasting, notifications and secrets
        # without installing a GNOME Shell session.
        xdg.portal = {
          enable = true;
          xdgOpenUsePortal = true;
          config = {
            common.default = [
              "gnome"
              "gtk"
            ];

            niri = {
              default = [
                "gnome"
                "gtk"
              ];
              "org.freedesktop.impl.portal.Access" = [ "gtk" ];
              "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
              "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
            };
          };
          extraPortals = [
            pkgs.xdg-desktop-portal-gnome
            pkgs.xdg-desktop-portal-gtk
          ];
        };
      };
  };
}

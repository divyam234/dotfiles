
{ den, ... }:
{
  den.aspects.portals = {
    nixos = { pkgs, ... }: {
      xdg.portal = {
        enable = true;
        config.common.default = [ "kde" ];
        extraPortals = [
          pkgs.kdePackages.xdg-desktop-portal-kde
          pkgs.xdg-desktop-portal-gtk
        ];
      };
    };
  };
}

{ den, ... }:
{
  den.aspects.desktop = {
    includes = [
      den.aspects.development
      den.aspects.fonts
      den.aspects.portals
      den.aspects.desktop-apps
      den.aspects.noctalia
      den.aspects.kde
      den.aspects.ghostty
    ];

    nixos =
      { user, ... }:
      {
        networking.networkmanager.enable = true;
        hardware.bluetooth.enable = true;
        security.polkit.enable = true;

        services = {
          dbus.enable = true;
          gvfs.enable = true;
          udisks2.enable = true;
          upower.enable = true;
          blueman.enable = true;
          pipewire = {
            enable = true;
            pulse.enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            jack.enable = true;
          };
        };

        users.users.${user.userName}.extraGroups = [
          "networkmanager"
          "audio"
          "video"
          "input"
          "render"
        ];

        environment.sessionVariables = {
          NIXOS_OZONE_WL = "1";
          MOZ_ENABLE_WAYLAND = "1";
          QT_QPA_PLATFORM = "wayland;xcb";
          SDL_VIDEODRIVER = "wayland";
        };
      };
  };
}

{ den, ... }:
{
  den.aspects.kde = {
    nixos = { pkgs, lib, user, ... }: {
      services = {
        # Plasma 6 desktop on Wayland with SDDM.
        xserver.enable = true;
        displayManager.sddm = {
          enable = true;
          wayland.enable = true;
          autoNumlock = true;
        };
        desktopManager.plasma6 = {
          enable = true;
          enableQt5Integration = true;
        };
      };

      programs.kdeconnect.enable = true;

      # Plasma/Wayland friendly defaults. Plasma itself will set most of these,
      # but keeping them explicit helps Electron/Chromium/Firefox apps choose Wayland.
      environment.sessionVariables = {
        NIXOS_OZONE_WL = "1";
        MOZ_ENABLE_WAYLAND = "1";
        QT_QPA_PLATFORM = "wayland;xcb";
        SDL_VIDEODRIVER = "wayland";
        XDG_CURRENT_DESKTOP = "KDE";
        KDE_SESSION_VERSION = "6";
        KDE_SESSION_TYPE = "wayland";
      };

      environment.systemPackages = with pkgs; [
        kdePackages.dolphin
        kdePackages.kate
        kdePackages.konsole
        kdePackages.ark
        kdePackages.okular
        kdePackages.gwenview
        kdePackages.spectacle
        kdePackages.filelight
        kdePackages.kcalc
        kdePackages.kcharselect
        kdePackages.plasma-systemmonitor
        kdePackages.plasma-browser-integration
        kdePackages.kdeconnect-kde
        kdePackages.partitionmanager
        kdePackages.qtstyleplugin-kvantum
        kdePackages.qtwayland
        libsForQt5.qt5ct
      ];

      users.users.${user.userName}.extraGroups = [
        "networkmanager"
        "audio"
        "video"
        "input"
        "render"
      ];
    };

    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        kdePackages.kate
        kdePackages.konsole
        kdePackages.okular
        kdePackages.spectacle
        kdePackages.filelight
      ];
    };
  };
}

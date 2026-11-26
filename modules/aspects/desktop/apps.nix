{ den, ... }:
{
  den.aspects.desktop-apps = {
    homeManager =
      { lib, pkgs, ... }:
      {
        home.packages = with pkgs; [
          baobab
          disktree
          foliate
          gnome-disk-utility
          gparted
          localsend
          mission-center
          pavucontrol
          pdfcraft
          wl-clipboard
          brightnessctl
          playerctl
          telegram-desktop
          vlc4
          obs-studio
          sonora
          probe
          ddcutil
          upower
        ];

        xdg.mimeApps = {
          enable = true;
          defaultApplications = lib.genAttrs [
            "video/mp4"
            "video/mpeg"
            "video/ogg"
            "video/quicktime"
            "video/webm"
            "video/x-matroska"
            "video/x-msvideo"
            "video/x-ms-wmv"
            "audio/aac"
            "audio/flac"
            "audio/mp4"
            "audio/mpeg"
            "audio/ogg"
            "audio/x-wav"
            "application/ogg"
            "application/x-matroska"
          ] (_: [ "vlc4.desktop" ]);
        };
      };
  };
}

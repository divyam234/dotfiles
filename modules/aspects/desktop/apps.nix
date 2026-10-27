{ den, ... }:
{
  den.aspects.desktop-apps = {
    homeManager =
      { pkgs, ... }:
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
          mpv
          telegram-desktop
          vlc4
          obs-studio
          sonora
          probe
          ddcutil
          upower
        ];
      };
  };
}

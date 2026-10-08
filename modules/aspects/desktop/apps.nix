{ den, ... }:
{
  den.aspects.desktop-apps = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          baobab
          easyeffects
          foliate
          gnome-disk-utility
          gparted
          localsend
          mission-center
          pavucontrol
          wl-clipboard
          brightnessctl
          playerctl
          mpv
          remmina
          telegram-desktop
          vlc
          obs-studio
          spotify
          spotify-player
          sonora
          cutter
          ida-pro
          httpie-desktop
          ddcutil
          upower
        ];
      };
  };
}

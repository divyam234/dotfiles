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
          obsidian
          telegram-desktop
          vlc
          obs-studio
          spotify
          spotify-player
          sonora
          cutter
          ida-pro
          androidenv.androidPkgs.platform-tools
          httpie-desktop
          ddcutil
          upower
          dbflux
        ];
      };
  };
}

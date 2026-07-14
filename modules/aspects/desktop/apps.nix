{ den, ... }:
{
  den.aspects.desktop-apps = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          baobab
          beekeeper-studio
          easyeffects
          foliate
          gnome-disk-utility
          gparted
          localsend
          mcontrolcenter
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
          cutter
          ida-pro
          androidenv.androidPkgs.platform-tools
          httpie-desktop
        ];
      };
  };
}

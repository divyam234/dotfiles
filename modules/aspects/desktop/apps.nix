{ den, ... }:
{
  den.aspects.desktop-apps = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          baobab
          burpsuitepro
          dbeaver-bin
          easyeffects
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
          solaar
          spotify
          telegram-desktop
          vesktop
          vlc
          obs-studio
          cutter
        ];
      };
  };
}

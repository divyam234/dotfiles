{ den, ... }:
{
  den.aspects.desktop-apps = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          baobab
          beekeeper-studio
          burpsuitepro
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
          telegram-desktop
          vesktop
          vlc
          obs-studio
          cutter
        ];
      };
  };
}

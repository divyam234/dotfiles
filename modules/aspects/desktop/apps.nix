{ den, ... }:
{
  den.aspects.desktop-apps = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          baobab
          dbeaver-bin
          easyeffects
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
          solaar
          spotify
          telegram-desktop
          vesktop
        ];
      };
  };
}

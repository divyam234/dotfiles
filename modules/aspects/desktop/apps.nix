{ den, ... }:
{
  den.aspects.desktop-apps = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          firefox
          chromium
          pavucontrol
          wl-clipboard
          brightnessctl
          playerctl
          imv
          mpv
          obsidian
          vesktop
        ];
      };
  };
}

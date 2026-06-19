{ den, ... }:
{
  den.aspects.desktop-apps = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          pavucontrol
          wl-clipboard
          brightnessctl
          playerctl
          mpv
          obsidian
          vesktop
        ];
      };
  };
}

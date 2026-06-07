
{ den, ... }:
{
  den.aspects.desktop-apps = {
    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        firefox
        chromium
        kdePackages.dolphin
        kdePackages.kate
        kdePackages.okular
        kdePackages.gwenview
        kdePackages.spectacle
        kdePackages.filelight
        kdePackages.kdeconnect-kde
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

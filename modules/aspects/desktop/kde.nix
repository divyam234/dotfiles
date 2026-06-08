{ den, ... }:
{
  den.aspects.kde = {
    nixos =
      { user, ... }:
      {
        users.users.${user.userName}.extraGroups = [
          "networkmanager"
          "audio"
          "video"
          "input"
          "render"
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          kdePackages.dolphin
          kdePackages.kate
          kdePackages.konsole
          kdePackages.ark
          kdePackages.okular
          kdePackages.gwenview
          kdePackages.spectacle
          kdePackages.filelight
          kdePackages.kcalc
          kdePackages.kcharselect
          kdePackages.plasma-systemmonitor
          kdePackages.plasma-browser-integration
          kdePackages.kdeconnect-kde
          kdePackages.partitionmanager
          kdePackages.qtstyleplugin-kvantum
          kdePackages.qtwayland
          libsForQt5.qt5ct
        ];
      };
  };
}

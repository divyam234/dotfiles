{ den, ... }:
{
  den.aspects.kde-packages = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          kdePackages.dolphin
          kdePackages.qtsvg
        ];
        stylix.targets.kde.enable = true;
        qt.enable = true;
      };
  };
}

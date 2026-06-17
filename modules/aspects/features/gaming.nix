{ den, ... }:
{
  den.aspects.gaming = {
    nixos = _: {
      programs.steam.enable = true;
      programs.gamemode.enable = true;
    };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          mangohud
          protonup-qt
          heroic
          lutris
        ];
      };
  };
}

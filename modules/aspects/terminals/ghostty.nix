{ den, ... }:
{
  den.aspects.ghostty = {
    homeManager =
      { pkgs, ... }:
      {
        programs.ghostty = {
          enable = true;
          enableFishIntegration = true;
          settings = {
            theme = "dark";
            font-size = 12;
            window-padding-x = 8;
            window-padding-y = 8;
          };
        };
      };
  };
}

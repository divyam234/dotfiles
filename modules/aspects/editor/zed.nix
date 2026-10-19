{ den, ... }:
{
  den.aspects.zed = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.zed-editor ];
        programs.zed-editor = {
          enable = true;
          extensions = [
            "nix"
            "toml"
            "kdl"
            "material-icon-theme"
          ];
          userSettings = {
            hour_format = "hour24";
            auto_update = false;
            window_decorations = "server";
            icon_theme = "Material Icon Theme";
          };
        };
      };
  };
}

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
          ];
          userSettings = {
            hour_format = "hour24";
            auto_update = false;
            window_decorations = "server";
          };
        };
      };
  };
}

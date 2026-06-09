{ inputs, den, ... }:
{
  flake-file.inputs.zjstatus.url = "github:dj95/zjstatus";

  den.aspects.zellij = {
    homeManager =
      { config, pkgs, ... }:
      let
        colors = config.lib.stylix.colors.withHashtag;
        zstatusLayout =
          builtins.replaceStrings
            [
              "#616e88"
              "#2E3440"
              "#3B4252"
              "#BF616A"
              "#A3BE8C"
              "#EBCB8B"
              "#81A1C1"
              "#B48EAD"
              "#88C0D0"
              "#E5E9F0"
              "#D08770"
              "#6C7086"
            ]
            [
              colors.base05
              colors.base00
              colors.base01
              colors.base08
              colors.base0B
              colors.base0A
              colors.base0D
              colors.base0E
              colors.base0C
              colors.base06
              colors.base09
              colors.base03
            ]
            (builtins.readFile ./layouts/default.kdl);
      in
      {
        home.packages = [ pkgs.tmate ];

        xdg.configFile = {
          "zellij/config.kdl".source = ./config.kdl;
          "zellij/layouts/default.kdl".source = ./layouts/default.kdl;
        };
        programs.zellij.enable = true;
      };
  };
}

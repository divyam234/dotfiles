{ inputs, den, ... }:
{

  den.aspects.zellij = {
    homeManager =
      { config, pkgs, ... }:
      let
        zellijConfig =
          builtins.replaceStrings [ "@zjstatus@" ] [ "file:${pkgs.zjstatus}/bin/zjstatus.wasm" ]
            (builtins.readFile ./config.kdl);
      in
      {
        home.packages = [
          pkgs.zjstatus
        ];
        programs.zellij.enable = true;
        xdg.configFile = {
          "zellij/config.kdl".text = zellijConfig;
          "zellij/layouts/default.kdl".source = ./layouts/default.kdl;
        };
      };
  };
}

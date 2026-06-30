{
  config,
  lib,
  options,
  pkgs,
  ...
}:

let
  isHomeManager = lib.hasAttrByPath [ "xdg" "configFile" ] options;
  cfg = config.stylix.targets.openchamber;
  input = pkgs.writeText "openchamber-stylix-opencode-theme.json" (
    builtins.toJSON {
      theme = config.programs.opencode.themes.stylix.theme;
    }
  );

  generated =
    pkgs.runCommand "openchamber-stylix-themes"
      {
        nativeBuildInputs = [ pkgs.bun ];
      }
      ''
        mkdir -p "$out"
        ${lib.getExe pkgs.bun} ${./port-opencode-theme.ts} --out-dir "$out" ${input}
      '';
in
{
  options.stylix.targets.openchamber.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.stylix.autoEnable or false;
    description = "Generate OpenChamber light and dark themes from the active Stylix Base16 palette.";
  };

  config = lib.optionalAttrs isHomeManager (
    lib.mkIf cfg.enable {
      xdg.configFile."openchamber/themes/stylix-dark.json".source = "${generated}/stylix-dark.json";

      xdg.configFile."openchamber/themes/stylix-light.json".source = "${generated}/stylix-light.json";
    }
  );
}

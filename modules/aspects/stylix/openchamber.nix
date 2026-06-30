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
  input = pkgs.writeText "stylix.json" (
    builtins.toJSON {
      theme = config.programs.opencode.themes.stylix.theme;
    }
  );

  portScript = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/openchamber/openchamber/f2f2498190fba4c3ffece61e61da330035f6f766/scripts/port-opencode-theme.ts";
    hash = "sha256-yX9UFrJWn2xYllIgPloGH0q5N8bkMd2CfQbWBee0bcA=";
  };

  resolverStub = pkgs.writeTextDir "packages/ui/src/theme/resolve.ts" ''
    export function resolveThemeVariant(variant: any, isDark: boolean): Record<string, string> {
      return {};
    }
  '';

  generated =
    pkgs.runCommand "openchamber-stylix-themes"
      {
        nativeBuildInputs = [ pkgs.bun ];
      }
      ''
        mkdir -p "$out"
        tmp=$(mktemp -d)
        cp "${input}" "$tmp/stylix.json"
        ${lib.getExe pkgs.bun} ${portScript} \
          "$tmp/stylix.json" \
          --opencode-root ${resolverStub} \
          --out-dir "$tmp" --force
        mv "$tmp"/stylix-dark.json "$out"/stylix-dark.json
        mv "$tmp"/stylix-light.json "$out"/stylix-light.json
        rm -rf "$tmp"
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

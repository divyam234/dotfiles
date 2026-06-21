{ inputs, den, ... }:
{
  flake-file.inputs.tinted-sublime-text = {
    url = "github:tinted-theming/tinted-sublime-text";
    flake = false;
  };

  den.aspects.sublime = {
    homeManager =
      {
        config,
        pkgs,
        ...
      }:
      let
        colors = config.lib.stylix.colors;
        tintedSublime = pkgs.runCommand "tinted-sublime-text-base16-nix-compatible" { } ''
          cp -R ${inputs.tinted-sublime-text} "$out"
          chmod -R u+w "$out"

          substituteInPlace "$out/templates/config.yaml" \
            --replace-fail \
              'supported-systems: [base16, base24]' \
              'supported-systems: [base16,base24]'
        '';

        colorScheme = colors {
          templateRepo = tintedSublime;
          target = "base16-color-scheme";
        };

        sublimeTheme = colors {
          templateRepo = tintedSublime;
          target = "base16-sublime-theme";
        };
      in
      {
        home.packages = [ pkgs.local.sublime ];

        xdg.configFile = {
          # The generated Tinted theme refers to resources through paths such
          # as tinted_theming/assets/close.png. Sublime requires the package
          # directory to have exactly this name.
          "sublime-text/Packages/tinted_theming".source = inputs.tinted-sublime-text;

          "sublime-text/Packages/User/Stylix.sublime-color-scheme".source = colorScheme;

          "sublime-text/Packages/User/Stylix.sublime-theme".source = sublimeTheme;

          "sublime-text/Packages/User/Preferences.sublime-settings".text = builtins.toJSON {
            theme = "Stylix.sublime-theme";
            color_scheme = "Packages/User/Stylix.sublime-color-scheme";

            font_face = config.stylix.fonts.monospace.name;
            font_size = 12;

            line_padding_top = 2;
            line_padding_bottom = 2;

            animation_enabled = false;
            caret_style = "smooth";

            highlight_line = true;
            highlight_gutter = true;
            highlight_modified_tabs = true;

            draw_minimap_border = true;
            always_show_minimap_viewport = true;
            overlay_scroll_bars = "enabled";

            # Tinted collapses the tab close button when this is false.
            show_tab_close_buttons = true;

            indent_guide_options = [
              "draw_normal"
              "draw_active"
            ];

            translate_tabs_to_spaces = true;
            trim_trailing_white_space_on_save = true;
          };
        };
      };
  };
}

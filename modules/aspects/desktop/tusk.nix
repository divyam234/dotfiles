{ ... }:
{
  den.aspects.tusk = {
    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        colors = config.lib.stylix.colors.withHashtag;
        palette = (pkgs.formats.toml { }).generate "tusk-stylix-colors.toml" {
          mode = if config.stylix.polarity == "light" then "light" else "dark";
          background = colors.base00;
          foreground = colors.base05;
          dark_background = colors.base01;
          lighter_background = colors.base02;
          bright_foreground = colors.base06;
          dark_foreground = colors.base04;
          muted = colors.base03;
          selection = colors.base02;
          accent = colors.base0D;
          red = colors.base08;
          orange = colors.base09;
          yellow = colors.base0A;
          green = colors.base0B;
          cyan = colors.base0C;
          blue = colors.base0D;
          magenta = colors.base0E;
          bright_blue = colors.base0D;
          bright_cyan = colors.base0C;
        };
        settings = (pkgs.formats.json { }).generate "tusk-stylix-settings.json" {
          appearance = "Omarchy";
          accent = "Theme";
          ui_font_family = config.stylix.fonts.sansSerif.name;
          ui_font_size = config.stylix.fonts.sizes.applications;
          table_font_family = config.stylix.fonts.monospace.name;
          table_font_size = config.stylix.fonts.sizes.terminal;
        };
        syncSettings = pkgs.writeShellApplication {
          name = "tusk-sync-theme";
          runtimeInputs = [
            pkgs.jq
            pkgs.procps
          ];
          text = ''
            data_dir="''${TUSK_DATA_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/tusk}"
            settings_file="$data_dir/settings.json"
            mkdir -p "$data_dir"
            tmp=$(mktemp "$data_dir/settings.json.XXXXXX")
            trap 'rm -f "$tmp"' EXIT
            if [ -f "$settings_file" ]; then
              jq --slurpfile theme ${settings} '. + $theme[0]' "$settings_file" > "$tmp"
              if jq -e --slurpfile desired "$tmp" '. == $desired[0]' "$settings_file" >/dev/null; then
                exit 0
              fi
            else
              cp ${settings} "$tmp"
            fi
            if pgrep -u "$(id -u)" -x tusk >/dev/null || pgrep -u "$(id -u)" -x .tusk-wrapped >/dev/null; then
              echo 'Close Tusk before applying its Stylix settings.' >&2
              exit 1
            fi
            chmod 600 "$tmp"
            mv "$tmp" "$settings_file"
          '';
        };
      in
      {
        home.packages = [ pkgs.tusk ];

        # Tusk reads this hard-coded Omarchy path and reloads the palette live.
        home.file.".local/state/omarchy/current/theme/colors.toml".source = palette;
        home.activation.tuskStylix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${syncSettings}/bin/tusk-sync-theme
        '';
      };
  };
}

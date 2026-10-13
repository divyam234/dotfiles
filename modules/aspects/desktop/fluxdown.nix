{ den, ... }:
{
  den.aspects.fluxdown = {
    homeManager =
      { config, pkgs, ... }:
      let
        colors = config.lib.stylix.colors.withHashtag;
        mode = if config.stylix.polarity == "light" then "light" else "dark";
        fluxdownTheme = {
          "$schema" = "https://fluxdown.zerx.dev/schemas/gpui-theme.v2.json";
          format = "fluxdown.gpui-theme";
          schemaVersion = 2;
          meta = {
            id = "stylix";
            name = "Stylix";
          };
          extends = "builtin:default-${mode}";
          tokens = {
            colors = {
              background = colors.base00;
              foreground = colors.base05;
              surface = colors.base01;
              surfaceForeground = colors.base05;
              primary = colors.base0D;
              primaryForeground = colors.base00;
              secondary = colors.base02;
              secondaryForeground = colors.base05;
              muted = colors.base02;
              mutedForeground = colors.base04;
              accent = "${colors.base0D}26";
              accentForeground = colors.base0D;
              destructive = colors.base08;
              destructiveForeground = colors.base00;
              border = colors.base03;
              input = colors.base03;
              ring = colors.base0D;
              success = colors.base0B;
              warning = colors.base0A;
              info = colors.base0C;
              textTertiary = colors.base04;
              hairline = colors.base02;
              rowHover = colors.base02;
              chrome = colors.base01;
              navHover = colors.base02;
              navSelected = colors.base02;
              navSelectedForeground = colors.base05;
              navSelectedIcon = colors.base0D;
              accentText = colors.base0D;
              caret = colors.base0D;
              textSelection = "${colors.base0D}4D";
              dragBorder = "${colors.base0D}A6";
              dropTarget = "${colors.base0D}33";
              statusDownloading = colors.base0D;
              statusCompleted = colors.base0B;
              statusFailed = colors.base08;
              statusPaused = colors.base0A;
              statusQueued = colors.base04;
              progressTrack = colors.base02;
              progressFill = colors.base0D;
            };
            typography = {
              sans = config.stylix.fonts.sansSerif.name;
              mono = config.stylix.fonts.monospace.name;
            };
          };
        };
        themeFile = (pkgs.formats.json { }).generate "fluxdown-stylix.json" fluxdownTheme;
        python = pkgs.python3.withPackages (ps: [ ps.websocket-client ]);
        syncTheme = pkgs.writeShellApplication {
          name = "fluxdown-sync-theme";
          text = ''
            exec ${python}/bin/python ${./fluxdown-theme.py} ${themeFile} ${mode}
          '';
        };
        themedFluxdown = pkgs.symlinkJoin {
          name = "${pkgs.fluxdown.name}-stylix";
          inherit (pkgs.fluxdown) pname version meta;
          paths = [ pkgs.fluxdown ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            rm "$out/bin/fluxdown-desktop"
            makeWrapper ${pkgs.fluxdown}/bin/fluxdown-desktop "$out/bin/fluxdown-desktop" \
              --run '${syncTheme}/bin/fluxdown-sync-theme &'
            rm "$out/share/applications/com.fluxdown.app.desktop"
            substitute ${pkgs.fluxdown}/share/applications/com.fluxdown.app.desktop \
              "$out/share/applications/com.fluxdown.app.desktop" \
              --replace-fail '${pkgs.fluxdown}/bin/fluxdown-desktop' "$out/bin/fluxdown-desktop"
          '';
        };
      in
      {
        home.packages = [ themedFluxdown ];

        xdg.configFile."fluxdown/themes/stylix.json".source = themeFile;
      };
  };
}

{ inputs, den, ... }:
{
  flake-file.inputs.noctalia = {
    url = "github:noctalia-dev/noctalia";
    #inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.noctalia = {

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        colors = config.lib.stylix.colors;
        # TODO: Remove this local Stylix target once the upstream Noctalia v5
        # target is merged into nix-community/stylix.
        palette = {
          dark = with colors.withHashtag; {
            mPrimary = base0D;
            mOnPrimary = base00;
            mSecondary = base0E;
            mOnSecondary = base00;
            mTertiary = base0C;
            mOnTertiary = base00;
            mError = base08;
            mOnError = base00;
            mSurface = base00;
            mOnSurface = base05;
            mHover = base0C;
            mOnHover = base00;
            mSurfaceVariant = base01;
            mOnSurfaceVariant = base04;
            mOutline = base03;
            mShadow = base00;

            terminal = {
              foreground = base05;
              background = base00;
              cursor = base05;
              cursorText = base00;
              selectionFg = base05;
              selectionBg = base02;
              normal = {
                black = base00;
                red = base08;
                green = base0B;
                yellow = base0A;
                blue = base0D;
                magenta = base0E;
                cyan = base0C;
                white = base05;
              };
              bright = {
                black = base03;
                red = base08;
                green = base0B;
                yellow = base0A;
                blue = base0D;
                magenta = base0E;
                cyan = base0C;
                white = base07;
              };
            };
          };
        };
      in
      {
        imports = [ inputs.noctalia.homeModules.default ];

        programs.noctalia = {
          enable = true;
          package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;

          # Niri starts the shell. Do not create a second lifecycle owner.
          systemd.enable = false;

          customPalettes.stylix = palette;

          # Keep the declarative layer small. GUI changes remain writable in
          # ~/.local/state/noctalia/settings.toml and override these defaults.
          settings = {
            theme = {
              mode = lib.mkOverride 60 (if config.stylix.polarity == "light" then "light" else "dark");
              source = lib.mkOverride 60 "custom";
              custom_palette = lib.mkOverride 60 "stylix";

              templates = {
                enable_builtin_templates = false;
              };
            };

            dock.background_opacity = lib.mkOverride 60 config.stylix.opacity.desktop;
            notification.background_opacity = lib.mkOverride 60 config.stylix.opacity.popups;
            osd.background_opacity = lib.mkOverride 60 config.stylix.opacity.popups;
            shell.font_family = lib.mkOverride 60 config.stylix.fonts.sansSerif.name;

            wallpaper.default.path = lib.mkOverride 60 "${../../../theme/wallpaper.png}";
          };
        };
      };
  };
}

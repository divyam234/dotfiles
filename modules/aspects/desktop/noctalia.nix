{ inputs, den, ... }:
{
  flake-file.inputs.noctalia = {
    url = "github:noctalia-dev/noctalia";
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

          systemd.enable = false;

          customPalettes.stylix = palette;

          settings = {
            bar.default = {
              background_opacity = 0.7;
              capsule = true;
              end = [
                "media"
                "tray"
                "notifications"
                "clipboard"
                "network"
                "bluetooth"
                "volume"
                "brightness"
                "control-center"
                "session"
              ];
              margin_ends = 20;
              padding = 12;
              scale = 1.1;
              start = [
                "launcher"
                "workspaces"
              ];
            };

            shell = {
              polkit_agent = true;
              animation.enabled = false;
            };
            theme = {
              mode = "dark";
              source = "custom";
              custom_palette = "stylix";
              templates = {
                enable_builtin_templates = false;
                enable_community_templates = false;
              };
            };
            shell.font_family = config.stylix.fonts.sansSerif.name;
            wallpaper.default.path = "${../../../theme/wallpaper.png}";
          };
        };
      };
  };
}

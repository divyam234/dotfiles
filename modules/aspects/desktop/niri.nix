{
  den,
  lib,
  ...
}:
let
  displayConfig = import ../../../lib/display-layout.nix { inherit lib; };
in
{
  # services.displayManager.noctalia-greeter is provided by nixpkgs upstream;
  # no flake input needed.
  den.schema.host =
    { config, lib, ... }:
    let
      positiveFloat = lib.types.addCheck lib.types.float (value: value > 0.0);
    in
    {
      options = {
        greeter = lib.mkOption {
          type = lib.types.submodule {
            options.output.scale = lib.mkOption {
              type = lib.types.nullOr positiveFloat;
              default = 1.25;
              description = "Noctalia Greeter output scale override.";
            };
          };
          default = { };
          description = "Host-specific greeter settings.";
        };

        outputs = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Output connector name (e.g. eDP-1, HDMI-A-1).";
                };
                mode = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "1920x1080@74.973";
                  description = "Display mode string.";
                };
                scale = lib.mkOption {
                  type = positiveFloat;
                  default = 1.0;
                  description = "Output scale factor.";
                };
                position = lib.mkOption {
                  type = lib.types.nullOr (
                    lib.types.submodule {
                      options = {
                        x = lib.mkOption {
                          type = lib.types.int;
                          default = 0;
                        };
                        y = lib.mkOption {
                          type = lib.types.int;
                          default = 0;
                        };
                      };
                    }
                  );
                  default = null;
                  description = "Output position.";
                };
                off = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether this output is disabled.";
                };
              };
            }
          );
          default = [ { name = "eDP-1"; } ];
          description = "Monitor output configuration for niri.";
        };
      };

      config.assertions = [
        {
          assertion = lib.all (output: !(output.off && output.mode != null)) config.outputs;
          message = "Disabled outputs must not declare a display mode.";
        }
      ];
    };

  den.aspects.niri = { user, ... }: {
    nixos =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        inherit (displayConfig host) greeterLayout greeterScale;
        colors = config.lib.stylix.colors.withHashtag;
      in
      {
        programs.niri = {
          enable = true;
          package = pkgs.niri;
        };

        services.displayManager.noctalia-greeter = {
          enable = true;
          package = pkgs.noctalia-greeter;

          extraArgs = [
            "--session"
            "niri"
            "--user"
            user.userName
          ];

          cursorTheme = {
            package = pkgs.bibata-cursors;
            name = "Bibata-Modern-Classic";
          };

          settings = {
            appearance = {
              scheme = "Synced";
              password_style = "random";
              theme_mode = if config.stylix.polarity == "light" then "light" else "dark";
              corner_radius_scale = 1.0;
              palette = {
                primary = colors.base0D;
                on_primary = colors.base00;
                secondary = colors.base0E;
                on_secondary = colors.base00;
                tertiary = colors.base0C;
                on_tertiary = colors.base00;
                error = colors.base08;
                on_error = colors.base00;
                surface = colors.base00;
                on_surface = colors.base05;
                surface_variant = colors.base01;
                on_surface_variant = colors.base04;
                outline = colors.base03;
                shadow = colors.base00;
                hover = colors.base0C;
                on_hover = colors.base00;
              };
              wallpaper = {
                path = "${../../../theme/wallpaper.png}";
                fill_mode = "crop";
              };
            };
            cursor.size = 24;
            output = {
              layout = greeterLayout;
              scale = greeterScale;
            };
            session.default = "niri";
            user.default = user.userName;
          };
        };

        environment.systemPackages = [ pkgs.xwayland-satellite ];
      };

    homeManager =
      {
        config,
        host,
        lib,
        ...
      }:
      let
        inherit (displayConfig host) outputs;
        colors = config.lib.stylix.colors;
        renderOutput =
          o:
          let
            mode = o.mode or null;
            scale = o.scale or 1.0;
            position = o.position or null;
          in
          ''
            output "${o.name}" {
                ${if o.off or false then "off" else ""}
                ${if mode != null then "mode \"${mode}\"" else ""}
                scale ${toString scale}
                ${if position != null then "position x=${toString position.x} y=${toString position.y}" else ""}
            }
          '';
        outputConfig = lib.concatStringsSep "\n" (map renderOutput outputs);
      in
      {
        xdg.configFile."niri/config.kdl".text =
          builtins.replaceStrings
            [
              "@active@"
              "@inactive@"
            ]
            [
              "#${colors.base0D}"
              "#${colors.base03}"
            ]
            (builtins.readFile ./niri/config.kdl)
          + lib.optionalString (outputs != [ ]) ("\n" + outputConfig);
      };
  };
}

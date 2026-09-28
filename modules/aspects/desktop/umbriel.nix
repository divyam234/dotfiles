{
  den,
  inputs,
  lib,
  ...
}:
let
  displayConfig = import ../../../lib/display-layout.nix { inherit lib; };
in
{
  flake-file.inputs.umbriel = {
    url = "github:noctalia-dev/umbriel";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Side-by-side with niri during the soak period. The greeter default stays
  # on niri (see niri.nix); Umbriel registers its own session via
  # services.displayManager.sessionPackages so it can be picked at login.
  den.aspects.umbriel = {
    nixos =
      { pkgs, ... }:
      {
        imports = [ inputs.umbriel.nixosModules.default ];

        programs.umbriel.enable = true;

        # Required on PATH for general.xwayland support (enabled by default).
        environment.systemPackages = [ pkgs.xwayland-satellite ];
      };

    homeManager =
      {
        config,
        host,
        ...
      }:
      let
        inherit (displayConfig host) outputs;
        colors = config.lib.stylix.colors;
        colorsHash = config.lib.stylix.colors.withHashtag;

        renderOutput =
          o:
          let
            off = o.off or false;
            position = o.position or null;
          in
          {
            enabled = !off;
          }
          // lib.optionalAttrs (!off && (o.mode or null) != null) { inherit (o) mode; }
          // lib.optionalAttrs (!off) { scale = o.scale or 1.0; }
          // lib.optionalAttrs (!off && position != null) {
            position = [
              position.x
              position.y
            ];
          };

        outputSettings = builtins.listToAttrs (
          map (o: {
            inherit (o) name;
            value = renderOutput o;
          }) outputs
        );
      in
      {
        imports = [ inputs.umbriel.homeModules.default ];

        programs.umbriel = {
          enable = true;
          settings = {
            general = {
              autostart = [ "noctalia" ];
              show_cheatsheet = false;
            };

            input.keyboard.numlock_toggle = true;
            input.touchpad = {
              tap = true;
              natural_scroll = true;
              disable_while_typing = true;
            };

            layout = {
              gap = 12;
              extent_presets = [
                0.333
                0.5
                0.667
              ];
              scrolling = {
                default_extent_fraction = 0.5;
                center_focused = "never";
              };
            };

            appearance = {
              prefer_no_csd = true;
              border_width = 2;
              outer_border_width = 0;
              corner_radius = 10;
              blur = {
                enabled = true;
                radius = 3;
              };
              shadow = {
                enabled = true;
                softness = 30;
                offset_x = 0;
                offset_y = 5;
              };
            };

            colors = {
              backdrop = "#000000FF";
              shadow = "#00000077";
              accent_primary = "#${colors.base0D}FF";
              border = {
                focused = "#${colors.base0D}FF";
                unfocused = "#${colors.base03}FF";
                outer = "#${colorsHash.base00}FF";
              };
            };

            output = outputSettings;

            keybinds = {
              "Mod" = "spawn:noctalia msg panel-toggle launcher";
              "Mod+Return" = {
                action = "spawn:ghostty";
                repeat = false;
              };
              "Mod+T" = {
                action = "spawn:ghostty";
                repeat = false;
              };
              "Mod+B" = {
                action = "spawn:brave";
                repeat = false;
              };
              "Mod+E" = {
                action = "spawn:nautilus --new-window";
                repeat = false;
              };
              "Mod+S" = {
                action = "spawn:gnome-text-editor";
                repeat = false;
              };
              "Mod+Space" = "spawn:noctalia msg panel-toggle launcher";
              "Mod+Shift+Space" = "spawn:noctalia msg panel-toggle control-center";
              "Mod+Ctrl+Space" = "spawn:noctalia msg panel-toggle session";
              "Mod+Shift+Comma" = "spawn:noctalia msg settings-toggle";
              "Super+Alt+L" = "spawn:noctalia msg session lock";

              "XF86AudioRaiseVolume" = {
                action = "spawn:noctalia msg volume-up";
                allow_when_locked = true;
              };
              "XF86AudioLowerVolume" = {
                action = "spawn:noctalia msg volume-down";
                allow_when_locked = true;
              };
              "XF86AudioMute" = {
                action = "spawn:noctalia msg volume-mute";
                allow_when_locked = true;
              };
              "XF86AudioMicMute" = {
                action = "spawn:noctalia msg mic-mute";
                allow_when_locked = true;
              };
              "XF86MonBrightnessUp" = {
                action = "spawn:noctalia msg brightness-up";
                allow_when_locked = true;
              };
              "XF86MonBrightnessDown" = {
                action = "spawn:noctalia msg brightness-down";
                allow_when_locked = true;
              };
              "XF86AudioPlay" = {
                action = "spawn:noctalia msg media toggle";
                allow_when_locked = true;
              };
              "XF86AudioPause" = {
                action = "spawn:noctalia msg media toggle";
                allow_when_locked = true;
              };
              "XF86AudioStop" = {
                action = "spawn:noctalia msg media stop";
                allow_when_locked = true;
              };
              "XF86AudioPrev" = {
                action = "spawn:noctalia msg media previous";
                allow_when_locked = true;
              };
              "XF86AudioNext" = {
                action = "spawn:noctalia msg media next";
                allow_when_locked = true;
              };

              "Mod+Shift+Slash" = {
                action = "cheatsheet-toggle";
                repeat = false;
              };
              "Mod+D" = {
                action = "overview-toggle";
                repeat = false;
              };
              "Mod+Tab" = {
                action = "overview-toggle";
                repeat = false;
              };
              "Mod+O" = {
                action = "overview-toggle";
                repeat = false;
              };
              "Mod+Q" = {
                action = "window-close";
                repeat = false;
              };
              "Mod+F1" = "window-focus-next";

              "Mod+Left" = "window-focus-left";
              "Mod+Down" = "window-focus-down";
              "Mod+Up" = "window-focus-up";
              "Mod+Right" = "window-focus-right";
              "Mod+H" = "window-focus-left";
              "Mod+J" = "workspace-next";
              "Mod+K" = "workspace-previous";
              "Mod+L" = "window-focus-right";
              "Mod+U" = "window-focus-down";
              "Mod+I" = "window-focus-up";

              "Mod+Ctrl+Left" = "column-move-left";
              "Mod+Ctrl+Down" = "window-move-down";
              "Mod+Ctrl+Up" = "window-move-up";
              "Mod+Ctrl+Right" = "column-move-right";
              "Mod+Ctrl+H" = "column-move-left";
              "Mod+Ctrl+J" = "window-move-down";
              "Mod+Ctrl+K" = "window-move-up";
              "Mod+Ctrl+L" = "column-move-right";

              "Mod+Shift+Left" = "output-focus-left";
              "Mod+Shift+Down" = "output-focus-down";
              "Mod+Shift+Up" = "output-focus-up";
              "Mod+Shift+Right" = "output-focus-right";

              "Mod+Shift+Ctrl+Left" = "column-move-to-output-left";
              "Mod+Shift+Ctrl+Down" = "column-move-to-output-down";
              "Mod+Shift+Ctrl+Up" = "column-move-to-output-up";
              "Mod+Shift+Ctrl+Right" = "column-move-to-output-right";

              "Mod+Page_Down" = "workspace-next";
              "Mod+Page_Up" = "workspace-previous";
              "Mod+Ctrl+Page_Down" = "column-move-to-workspace-next";
              "Mod+Ctrl+Page_Up" = "column-move-to-workspace-previous";

              "Mod+WheelDown" = {
                action = "workspace-next";
                cooldown_ms = 150;
              };
              "Mod+WheelUp" = {
                action = "workspace-previous";
                cooldown_ms = 150;
              };
              "Mod+Ctrl+WheelDown" = {
                action = "column-move-to-workspace-next";
                cooldown_ms = 150;
              };
              "Mod+Ctrl+WheelUp" = {
                action = "column-move-to-workspace-previous";
                cooldown_ms = 150;
              };

              "Mod+1" = "workspace-switch:1";
              "Mod+2" = "workspace-switch:2";
              "Mod+3" = "workspace-switch:3";
              "Mod+4" = "workspace-switch:4";
              "Mod+5" = "workspace-switch:5";
              "Mod+6" = "workspace-switch:6";
              "Mod+7" = "workspace-switch:7";
              "Mod+8" = "workspace-switch:8";
              "Mod+9" = "workspace-switch:9";

              "Mod+Ctrl+1" = "column-move-to-workspace:1";
              "Mod+Ctrl+2" = "column-move-to-workspace:2";
              "Mod+Ctrl+3" = "column-move-to-workspace:3";
              "Mod+Ctrl+4" = "column-move-to-workspace:4";
              "Mod+Ctrl+5" = "column-move-to-workspace:5";
              "Mod+Ctrl+6" = "column-move-to-workspace:6";
              "Mod+Ctrl+7" = "column-move-to-workspace:7";
              "Mod+Ctrl+8" = "column-move-to-workspace:8";
              "Mod+Ctrl+9" = "column-move-to-workspace:9";

              "Mod+Shift+1" = "window-move-to-workspace:1";
              "Mod+Shift+2" = "window-move-to-workspace:2";
              "Mod+Shift+3" = "window-move-to-workspace:3";
              "Mod+Shift+4" = "window-move-to-workspace:4";
              "Mod+Shift+5" = "window-move-to-workspace:5";
              "Mod+Shift+6" = "window-move-to-workspace:6";
              "Mod+Shift+7" = "window-move-to-workspace:7";
              "Mod+Shift+8" = "window-move-to-workspace:8";
              "Mod+Shift+9" = "window-move-to-workspace:9";

              "Mod+BracketLeft" = "window-consume-or-expel-left";
              "Mod+BracketRight" = "window-consume-or-expel-right";
              "Mod+Comma" = "window-consume-left";
              "Mod+Period" = "window-consume-right";

              "Mod+R" = "window-cycle-primary-extent";
              "Mod+Shift+R" = "window-cycle-primary-extent-back";
              "Mod+F" = "window-toggle-maximize";
              "Mod+Shift+F" = "window-toggle-fullscreen";
              "Mod+M" = "window-toggle-maximize-to-edges";
              "Mod+C" = "column-center";
              # Niri Mod+W (tabbed column display) has no Umbriel equivalent;
              # cycle the workspace layout mode instead.
              "Mod+W" = "workspace-set-layout:toggle";
              "Mod+Minus" = "window-modify-primary-extent:-0.1";
              "Mod+Equal" = "window-modify-primary-extent:0.1";
              "Mod+Shift+Minus" = "window-modify-secondary-extent:-0.1";
              "Mod+Shift+Equal" = "window-modify-secondary-extent:0.1";
              "Mod+V" = {
                action = "window-toggle-floating";
                repeat = false;
              };
              "Mod+Shift+V" = "window-focus-switch-floating";
              "Mod+P" = "window-toggle-pinned";

              # Scratchpad lives on Backslash so Niri's Space-based Noctalia
              # binds stay untouched.
              "Mod+Backslash" = "scratchpad-toggle";
              "Mod+Shift+Backslash" = {
                action = "window-move-to-scratchpad";
                repeat = false;
              };
              "Mod+Ctrl+Backslash" = {
                action = "window-restore-from-scratchpad";
                repeat = false;
              };

              "Mod+Escape" = {
                action = "shortcuts-inhibit-toggle";
                allow_when_inhibited = true;
                repeat = false;
              };
              "Mod+Shift+E" = "session-quit";
              "Ctrl+Alt+Delete" = "session-quit:skip-confirmation";
              "Mod+Shift+P" = "dpms-off";
            };

            window_rule = [
              {
                blur = true;
                blur_optimized = false;
              }
              {
                match.app_id = "^dev[.]noctalia[.]Noctalia[.]Settings$";
                default_floating = true;
              }
              {
                match.app_id = "^dev[.]noctalia[.]Noctalia$";
                default_floating = true;
                default_floating_size_px = {
                  width = 1020;
                  height = 900;
                };
              }
              {
                match.app_id = "brave-browser$";
                match.title = "(?i)picture.?in.?picture";
                default_floating = true;
                default_maximize = false;
                default_position = {
                  x = 20;
                  y = 20;
                  anchor = "bottom_right";
                };
              }
              {
                match.app_id = "^org[.]gnome[.]";
                border_width = 0;
                corner_radius = 12;
              }
              {
                match.app_id = "^(org[.]wezfurlong[.]wezterm|Alacritty|zen|com[.]mitchellh[.]ghostty|kitty)$";
                border_width = 0;
              }
              {
                match.app_id = "^(gnome-calculator|galculator|blueman-manager|org[.]gnome[.]Nautilus|xdg-desktop-portal)$";
                default_floating = true;
              }
              {
                match.app_id = "^(gnome-control-center|pavucontrol|nm-connection-editor)$";
                default_floating = false;
                default_scrolling_extent = 0.5;
              }
              {
                opacity = 0.9;
              }
              {
                match.app_id = "^vlc$";
                opacity = 1.0;
              }
            ];

            layer_rule = [
              {
                match.namespace = "^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd|desktop-widget-[^\"]*)$";
                blur = true;
                blur_ignore_alpha = 0.5;
                blur_popups = true;
                blur_optimized = false;
              }
            ];
          };
        };
      };
  };
}

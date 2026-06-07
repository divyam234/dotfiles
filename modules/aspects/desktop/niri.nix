{ den, ... }:
{
  den.aspects.niri = {
    nixos = { pkgs, user, ... }: {
      # Niri is the active compositor/session.
      # There is intentionally no Plasma/KWin/SDDM here.
      programs.niri.enable = true;

      services.greetd = {
        enable = true;
        settings.default_session = {
          user = "greeter";
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --remember-user-session --cmd ${pkgs.niri}/bin/niri-session";
        };
      };

      environment.systemPackages = with pkgs; [
        niri
        xwayland-satellite
        fuzzel
        swaybg
        swayidle
        swaylock
        wl-clipboard
        cliphist
        grim
        slurp
        swappy
        wf-recorder
        playerctl
        brightnessctl
        xdg-utils
      ];

      environment.sessionVariables = {
        NIXOS_OZONE_WL = "1";
        MOZ_ENABLE_WAYLAND = "1";
        QT_QPA_PLATFORM = "wayland;xcb";
        SDL_VIDEODRIVER = "wayland";
        CLUTTER_BACKEND = "wayland";
        GDK_BACKEND = "wayland,x11";
        XDG_CURRENT_DESKTOP = "niri";
      };

      users.users.${user.userName}.extraGroups = [
        "video"
        "input"
        "render"
      ];
    };

    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        fuzzel
        swaybg
        swayidle
        swaylock
        wl-clipboard
        cliphist
        grim
        slurp
        swappy
        wf-recorder
      ];

      xdg.configFile."niri/config.kdl".text = ''
        // Main compositor config.
        // KDE is only used for applications/frameworks; Niri owns the session.

        input {
            keyboard {
                xkb {
                    layout "us"
                }
            }

            touchpad {
                tap
                natural-scroll
            }

            mouse {
                accel-speed 0.0
            }
        }

        layout {
            gaps 12
            center-focused-column "never"

            preset-column-widths {
                proportion 0.33333
                proportion 0.5
                proportion 0.66667
            }

            default-column-width {
                proportion 0.5
            }

            focus-ring {
                width 2
                active-color "#7fc8ff"
                inactive-color "#505050"
            }

            border {
                off
            }

            shadow {
                on
                softness 30
                spread 5
                offset x=0 y=5
                color "#00000070"
            }
        }

        prefer-no-csd

        spawn-at-startup "sh" "-lc" "wl-paste --watch cliphist store"
        spawn-at-startup "swaybg" "-i" "${../../../theme/wallpaper.png}" "-m" "fill"

        screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

        binds {
            Mod+Return { spawn "ghostty"; }
            Mod+D { spawn "fuzzel"; }
            Mod+Q { close-window; }

            Mod+Left  { focus-column-left; }
            Mod+Right { focus-column-right; }
            Mod+Up    { focus-window-up; }
            Mod+Down  { focus-window-down; }

            Mod+Shift+Left  { move-column-left; }
            Mod+Shift+Right { move-column-right; }
            Mod+Shift+Up    { move-window-up; }
            Mod+Shift+Down  { move-window-down; }

            Mod+F { maximize-column; }
            Mod+Shift+F { fullscreen-window; }

            Mod+Minus { set-column-width "-10%"; }
            Mod+Equal { set-column-width "+10%"; }

            Mod+1 { focus-workspace 1; }
            Mod+2 { focus-workspace 2; }
            Mod+3 { focus-workspace 3; }
            Mod+4 { focus-workspace 4; }
            Mod+5 { focus-workspace 5; }

            Mod+Shift+1 { move-column-to-workspace 1; }
            Mod+Shift+2 { move-column-to-workspace 2; }
            Mod+Shift+3 { move-column-to-workspace 3; }
            Mod+Shift+4 { move-column-to-workspace 4; }
            Mod+Shift+5 { move-column-to-workspace 5; }

            Print { screenshot; }
            Mod+Print { screenshot-screen; }
            Shift+Print { screenshot-window; }

            XF86AudioRaiseVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
            XF86AudioLowerVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
            XF86AudioMute { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }

            XF86MonBrightnessUp { spawn "brightnessctl" "set" "5%+"; }
            XF86MonBrightnessDown { spawn "brightnessctl" "set" "5%-"; }
        }

        window-rule {
            geometry-corner-radius 12
            clip-to-geometry true
        }
      '';
    };
  };
}

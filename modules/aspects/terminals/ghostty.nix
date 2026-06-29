{ den, ... }:
{
  den.aspects.ghostty = {
    homeManager =
      { pkgs, ... }:
      {
        programs.ghostty = {
          enable = true;
          enableFishIntegration = true;
          settings = {
            font-size = 12;
            font-thicken = true;
            window-decoration = false;
            window-padding-x = 8;
            window-padding-y = 4;
            window-padding-balance = true;
            background-opacity = 1.0;
            background-blur-radius = 32;
            cursor-style = "bar";
            cursor-style-blink = false;
            scrollback-limit = 10000;
            mouse-hide-while-typing = true;
            copy-on-select = false;
            confirm-close-surface = false;
            app-notifications = "no-clipboard-copy,no-config-reload";
            shell-integration = "detect";
            shell-integration-features = "cursor,sudo,title,no-cursor";
            gtk-titlebar = false;
            keybind = [
              "ctrl+plus=increase_font_size:1"
              "ctrl+minus=decrease_font_size:1"
              "ctrl+zero=reset_font_size"
              "shift+enter=text:\\n"
            ];
          };
        };
      };
  };
}

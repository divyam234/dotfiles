{ den, ... }:
{
  den.aspects.noctalia = {

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        programs.noctalia = {
          enable = true;
          package = pkgs.noctalia;

          systemd.enable = false;

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
            # Theme source, palette, mode, font, and wallpaper are owned by
            # the upstream stylix noctalia target (auto-enabled).
            theme.templates = {
              enable_builtin_templates = false;
              enable_community_templates = false;
            };
          };
        };
      };
  };
}

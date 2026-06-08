{ ... }:
{
  den.aspects.server = {
    homeManager =
      { lib, ... }:
      {
        programs.zellij = lib.mkForce {
          enable = true;
          settings = {
            # theme set via zellij aspect config
            default_layout = "compact";
            pane_frames = false;
            simplified_ui = true;
            copy_on_select = true;
            show_startup_tips = false;
          };
        };
      };
  };
}

{ ... }:
{
  den.aspects.tern = {
    homeManager =
      { config, pkgs, ... }:
      {
        home.packages = [ pkgs.tern ];

        # Keep this declarative file authoritative if Tern replaces the managed link.
        xdg.configFile."tern/settings.json".force = true;
        xdg.configFile."tern/settings.json".text = builtins.toJSON {
          theme = "System";
          cursor = {
            glide = 80;
          };
          font_size = config.stylix.fonts.sizes.terminal + 1;
          ui_font_size = config.stylix.fonts.sizes.applications + 2;
          font_family = config.stylix.fonts.monospace.name;
          agent_command = "omp";
          adjust_cell_height = "10%";
          system_title_bar = true;
          opacity = 100;
          blur = 0;
          command_lenses = false;
          surface_fold = true;
          composer_text = "Markdown";
          agent_placement = "new_tab";
          native_prompt = false;
          auto_update = false;
          snap_text = true;
          sync_to_display = false;
          frames_queued = 2;
          file_tree.hidden = false;
          git = {
            auto_fetch_minutes = 0;
            sidebar_folded = [
              "remotes"
              "worktrees"
              "submodules"
              "branches"
            ];
          };
          sqlite = {
            editor_font_size = 9;
            results_font_size = 9;
          };
        };
      };
  };
}

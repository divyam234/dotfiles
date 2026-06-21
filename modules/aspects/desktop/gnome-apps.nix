{ den, ... }:
{
  den.aspects.gnome-apps = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          adw-gtk3
          nemo-with-extensions
          pix
          evince
          file-roller
          kdePackages.kate
          nwg-look
        ];

        dconf.settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            gtk-theme = "adw-gtk3";
          };

          "org/gtk/settings/file-chooser" = {
            sort-directories-first = true;
          };

          "org/cinnamon/desktop/applications/terminal" = {
            exec = "ghostty";
            exec-arg = "--working-directory";
          };
        };

        xdg.mimeApps = {
          enable = true;
          defaultApplications = {
            "inode/directory" = [ "nemo.desktop" ];
            "application/x-gnome-saved-search" = [ "nemo.desktop" ];
            "application/pdf" = [ "org.gnome.Evince.desktop" ];
            "image/jpeg" = [ "pix.desktop" ];
            "image/png" = [ "pix.desktop" ];
            "image/webp" = [ "pix.desktop" ];
            "image/gif" = [ "pix.desktop" ];
            "application/json" = [ "sublime-text.desktop" ];
            "application/x-shellscript" = [ "sublime-text.desktop" ];
            "text/markdown" = [ "sublime-text.desktop" ];
            "text/plain" = [ "sublime-text.desktop" ];
          };
        };
      };
  };
}

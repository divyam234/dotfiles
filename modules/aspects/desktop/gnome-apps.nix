{ den, ... }:
{
  den.aspects.gnome-apps = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          nautilus
          loupe
          evince
          file-roller
          gnome-text-editor
          gnome-calculator
        ];

        dconf.settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
          };

          "org/gnome/nautilus/preferences" = {
            default-folder-viewer = "list-view";
            show-create-link = true;
            show-delete-permanently = true;
            show-image-thumbnails = "always";
          };

          "org/gtk/settings/file-chooser" = {
            sort-directories-first = true;
          };
        };

        xdg.mimeApps = {
          enable = true;
          defaultApplications = {
            "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
            "application/pdf" = [ "org.gnome.Evince.desktop" ];
            "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
            "image/png" = [ "org.gnome.Loupe.desktop" ];
            "image/webp" = [ "org.gnome.Loupe.desktop" ];
            "image/gif" = [ "org.gnome.Loupe.desktop" ];
            "text/plain" = [ "org.gnome.TextEditor.desktop" ];
          };
        };
      };
  };
}

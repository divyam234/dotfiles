{ den, ... }:
{
  den.aspects.fastfetch = {
    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        colors = config.lib.stylix.colors.withHashtag;
        nixosLogo = ../../../theme/fastfetch-logo.png;
        fetchImg = pkgs.writeShellScriptBin "fetch-img" ''
          exec ${lib.getExe pkgs.fastfetch} --kitty-direct ${nixosLogo} --logo-width 40 --logo-height 13 "$@"
        '';
      in
      {
        programs.fastfetch = {
          enable = true;
          settings = {
            "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
            logo = {
              type = "small";
              source = "nixos_small";
              padding = {
                top = 1;
                right = 3;
              };
              color = {
                "1" = colors.base0D;
                "2" = colors.base0C;
              };
            };
            display = {
              separator = "  ";
              color = {
                keys = colors.base0D;
                title = colors.base0E;
              };
              key = {
                width = 12;
              };
            };
            modules = [
              "title"
              "separator"
              {
                type = "os";
                key = "OS";
              }
              {
                type = "host";
                key = "Host";
              }
              {
                type = "kernel";
                key = "Kernel";
              }
              {
                type = "uptime";
                key = "Uptime";
              }
              {
                type = "packages";
                key = "Packages";
              }
              {
                type = "shell";
                key = "Shell";
              }
              {
                type = "terminal";
                key = "Terminal";
              }
              {
                type = "de";
                key = "Desktop";
              }
              {
                type = "wm";
                key = "WM";
              }
              "break"
              {
                type = "cpu";
                key = "CPU";
              }
              {
                type = "gpu";
                key = "GPU";
              }
              {
                type = "memory";
                key = "Memory";
              }
              {
                type = "disk";
                key = "Disk";
              }
              "break"
              "colors"
            ];
          };
        };

        home.packages = [ fetchImg ];
      };
  };
}

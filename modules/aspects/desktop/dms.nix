{ inputs, den, ... }:
let
  dmsHome =
    { pkgs, ... }:
    {
      imports = [
        inputs.niri-nix.homeModules.default
        inputs.dms.homeModules.dank-material-shell
        inputs.dms.homeModules.niri
      ];

      wayland.windowManager.niri.enable = true;

      programs.dank-material-shell = {
        enable = true;
        package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;

        systemd.enable = false;

        niri = {
          enableSpawn = true;
          includes = {
            enable = true;
            override = false;
            originalFileName = "hm";
            filesToInclude = [
              "alttab"
              "binds"
              "layout"
              "outputs"
              "wpblur"
            ];
          };
        };
      };

      # DMS niri include files (alttab, binds, layout, outputs, wpblur)
      # are installed by the DMS package. With override = false, we add
      # the includes here via extraConfig instead of letting DMS replace
      # the entire config.kdl (which would lose Stylix colors).
      programs.niri.extraConfig = ''
        include "dms/alttab.kdl"
        include "dms/binds.kdl"
        include "dms/layout.kdl"
        include "dms/outputs.kdl"
        include "dms/wpblur.kdl"
      '';
    };
in
{
  den.aspects.dms = {
    nixos =
      { pkgs, user, ... }:
      {
        imports = [
          inputs.niri-nix.nixosModules.default
          inputs.dms.nixosModules.greeter
        ];

        programs.niri.enable = true;

        services.greetd.settings.default_session.user = "greeter";

        programs.dank-material-shell.greeter = {
          enable = true;
          package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
          configHome = "/home/${user.userName}";

          compositor = {
            name = "niri";
            customConfig = ''
              hotkey-overlay {
                  skip-at-startup
              }

              environment {
                  DMS_RUN_GREETER "1"
              }

              gestures {
                  hot-corners {
                      off
                  }
              }

              layout {
                  background-color "#000000"
              }
            '';
          };
        };

        users.users.${user.userName}.extraGroups = [
          "video"
          "input"
          "render"
        ];

        home-manager.users.${user.userName} = dmsHome;
      };

    homeManager = dmsHome;
  };
}

{ inputs, den, ... }:
let
  dmsHome =
    { pkgs, ... }:
    {
      imports = [
        inputs.niri-nix.homeModules.default
        inputs.dms.homeModules.dank-material-shell
      ];

      wayland.windowManager.niri.enable = true;

      programs.dank-material-shell = {
        enable = true;
        package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;

        systemd.enable = false;

        # Do not import inputs.dms.homeModules.niri here. The current DMS niri
        # Home Manager module expects config.lib.niri.actions and can fail during
        # non-desktop/server flake checks before the niri HM lib is available.
        # Keep Niri enabled through niri-nix and include the DMS-generated KDL
        # snippets explicitly via programs.niri.extraConfig below.
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
      };

    homeManager = dmsHome;
  };
}

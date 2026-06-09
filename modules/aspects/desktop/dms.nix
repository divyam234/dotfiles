{ inputs, den, ... }:
let
  dmsHome =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      dmsNiriIncludes = [
        ''include "dms/alttab.kdl"''
        ''include "dms/binds.kdl"''
        ''include "dms/layout.kdl"''
        ''include "dms/outputs.kdl"''
        ''include "dms/wpblur.kdl"''
      ];
    in
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
        # Home Manager module expects config.lib.niri.actions from a different
        # niri module family and fails during flake checks with this pinned
        # BANanaD3V/niri-nix input.
      };

      # BANanaD3V/niri-nix does not expose the Home Manager option
      # `programs.niri.extraConfig`. Keep the DMS KDL snippets wired by appending
      # the include lines after Home Manager has written the rest of the profile.
      home.activation.dmsNiriIncludes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        config_file=${lib.escapeShellArg "${config.xdg.configHome}/niri/config.kdl"}
        mkdir -p "$(dirname "$config_file")"
        touch "$config_file"

        ${lib.concatMapStringsSep "\n" (line: ''
          if ! grep -qxF ${lib.escapeShellArg line} "$config_file"; then
            printf '%s\n' ${lib.escapeShellArg line} >> "$config_file"
          fi
        '') dmsNiriIncludes}
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

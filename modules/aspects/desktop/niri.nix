{ inputs, den, ... }:
{
  flake-file.inputs.noctalia-greeter = {
    url = "github:noctalia-dev/noctalia-greeter";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.niri = {
    nixos =
      {
        pkgs,
        user,
        ...
      }:
      {
        imports = [
          inputs.noctalia-greeter.nixosModules.default
        ];

        programs.niri = {
          enable = true;
          package = pkgs.niri;
        };

        services.greetd = {
          enable = true;
          settings.default_session.user = "greeter";
        };

        programs.noctalia-greeter = {
          enable = true;
          package = inputs.noctalia-greeter.packages.${pkgs.stdenv.hostPlatform.system}.default;

          # Must match a session listed by `noctalia-greeter sessions`. The
          # greeter output layout is synced from Noctalia Shell after first
          # login because greeter needs connector names, not Niri display names.
          greeter-args = "--session niri --user ${user.userName}";

          settings.cursor = {
            theme = "Bibata-Modern-Classic";
            size = 24;
            package = pkgs.bibata-cursors;
          };
        };

        environment.systemPackages = [ pkgs.xwayland-satellite ];
      };

    homeManager =
      { config, ... }:
      let
        colors = config.lib.stylix.colors;
      in
      {
        xdg.configFile."niri/config.kdl".text =
          builtins.replaceStrings
            [
              "@active@"
              "@inactive@"
            ]
            [
              "#${colors.base0D}"
              "#${colors.base03}"
            ]
            (builtins.readFile ./niri/config.kdl);
      };
  };
}

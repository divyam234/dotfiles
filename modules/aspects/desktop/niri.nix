{ inputs, den, ... }:
{
  flake-file.inputs.niri = {
    url = "github:sodiboo/niri-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.niri = {
    nixos =
      { pkgs, ... }:
      {
        imports = [ inputs.niri.nixosModules.niri ];

        programs.niri.enable = true;

        services.greetd = {
          enable = true;
          settings.default_session = {
            user = "greeter";
            command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --cmd ${pkgs.niri}/bin/niri-session";
          };
        };

        environment.systemPackages = with pkgs; [
          tuigreet
          xwayland-satellite
        ];
      };

    homeManager =
      { config, ... }:
      let
        colors = config.lib.stylix.colors;
      in
      {
        programs.niri.config =
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

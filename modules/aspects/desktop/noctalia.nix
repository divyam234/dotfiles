{ inputs, den, ... }:
{
  flake-file.inputs.niri-nix = {
    url = "git+https://codeberg.org/BANanaD3V/niri-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.noctalia = {
    nixos =
      { pkgs, user, ... }:
      {
        imports = [ inputs.niri-nix.nixosModules.default ];

        programs.niri.enable = true;

        services.greetd = {
          enable = true;
          settings.default_session = {
            user = user.userName;
            command = "${pkgs.niri}/bin/niri-session";
          };
        };

        environment.systemPackages = with pkgs; [ noctalia-shell ];

        users.users.${user.userName}.extraGroups = [
          "video"
          "input"
          "render"
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        imports = [ inputs.niri-nix.homeModules.default ];

        home.packages = with pkgs; [ noctalia-shell ];

        systemd.user.services.noctalia = {
          Unit = {
            Description = "Noctalia desktop shell";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${pkgs.noctalia-shell}/bin/noctalia-shell";
            Restart = "on-failure";
            RestartSec = "3s";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        xdg.configFile."niri/config.kdl".text = ''
          spawn-at-startup "systemctl" "--user" "start" "noctalia.service"

          hotkey-overlay {
              skip-at-startup
          }
        '';
      };
  };
}

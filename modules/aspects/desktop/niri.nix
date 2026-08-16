{
  inputs,
  den,
  lib,
  ...
}:
let
  displayConfig = import ../../../lib/display-layout.nix { inherit lib; };
in
{
  flake-file.inputs.noctalia-greeter = {
    url = "github:noctalia-dev/noctalia-greeter";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.niri = {
    nixos =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        inherit (displayConfig host) greeterLayout greeterScale;
        colors = config.lib.stylix.colors.withHashtag;
        greeterAppearance = pkgs.formats.json { };
        greeterAppearanceJson = greeterAppearance.generate "appearance.json" {
          version = 1;
          theme_mode = if config.stylix.polarity == "light" then "light" else "dark";
          corner_radius_scale = 1.0;
          palette = {
            primary = colors.base0D;
            on_primary = colors.base00;
            secondary = colors.base0E;
            on_secondary = colors.base00;
            tertiary = colors.base0C;
            on_tertiary = colors.base00;
            error = colors.base08;
            on_error = colors.base00;
            surface = colors.base00;
            on_surface = colors.base05;
            surface_variant = colors.base01;
            on_surface_variant = colors.base04;
            outline = colors.base03;
            shadow = colors.base00;
            hover = colors.base0C;
            on_hover = colors.base00;
          };
          wallpaper = {
            path = "/var/lib/noctalia-greeter/wallpaper.png";
            fill_mode = "crop";
          };
        };
        greeterConfig = pkgs.formats.toml { };
        greeterToml = greeterConfig.generate "greeter.toml" {
          appearance.password_style = "random";
          output = {
            layout = greeterLayout;
            scale = greeterScale;
          };
          session.default = "niri";
          user.default = host.user;
        };
      in
      {
        imports = [
          inputs.noctalia-greeter.nixosModules.default
        ];

        programs.niri = {
          enable = true;
          package = pkgs.niri;
        };

        programs.noctalia-greeter = {
          enable = true;
          package = inputs.noctalia-greeter.packages.${pkgs.stdenv.hostPlatform.system}.default;

          greeter-args = "--session niri --user ${host.user}";

          settings = {
            cursor = {
              theme = "Bibata-Modern-Classic";
              size = 24;
              package = pkgs.bibata-cursors;
            };
          };
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/noctalia-greeter 0750 greeter greeter -"
        ];

        systemd.tmpfiles.settings."10-noctalia-greeter"."/var/lib/noctalia-greeter/greeter.toml".C =
          lib.mkForce
            {
              argument = "${greeterToml}";
              user = "greeter";
              group = "greeter";
              mode = "0644";
            };

        system.activationScripts.noctaliaGreeterFiles.text = ''
          ${pkgs.coreutils}/bin/install -d -m 0750 -o greeter -g greeter /var/lib/noctalia-greeter
          ${pkgs.coreutils}/bin/install -m 0644 -o greeter -g greeter ${greeterAppearanceJson} /var/lib/noctalia-greeter/appearance.json
          ${pkgs.coreutils}/bin/install -m 0640 -o greeter -g greeter ${greeterToml} /var/lib/noctalia-greeter/greeter.toml
          ${pkgs.coreutils}/bin/install -m 0644 -o greeter -g greeter ${../../../theme/wallpaper.png} /var/lib/noctalia-greeter/wallpaper.png
        '';

        environment.systemPackages = [ pkgs.xwayland-satellite ];
      };

    homeManager =
      {
        config,
        host,
        lib,
        ...
      }:
      let
        inherit (displayConfig host) outputs;
        colors = config.lib.stylix.colors;
        renderOutput =
          o:
          let
            mode = o.mode or null;
            scale = o.scale or 1.0;
            position = o.position or null;
          in
          ''
            output "${o.name}" {
                ${if o.off or false then "off" else ""}
                ${if mode != null then "mode \"${mode}\"" else ""}
                scale ${toString scale}
                ${if position != null then "position x=${toString position.x} y=${toString position.y}" else ""}
            }
          '';
        outputConfig = lib.concatStringsSep "\n" (map renderOutput outputs);
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
            (builtins.readFile ./niri/config.kdl)
          + lib.optionalString (outputs != [ ]) ("\n" + outputConfig);
      };
  };
}

{
  inputs,
  den,
  lib,
  ...
}:
{
  flake-file.inputs.noctalia-greeter = {
    url = "github:noctalia-dev/noctalia-greeter";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.niri =
    { host, ... }:
    let
      rawOutputs = host.outputs or [ ];
      greeterOutput = (host.greeter or { }).output or { };
      greeterScale = greeterOutput.scale or 1.25;

      round = value: builtins.floor (value + 0.5);
      parseModeWidth =
        mode:
        let
          match = builtins.match "([0-9]+)x[0-9]+.*" mode;
        in
        if match == null then null else builtins.fromJSON (builtins.elemAt match 0);
      logicalWidth =
        scaleOf: o:
        let
          mode = o.mode or (throw "Active output ${o.name} needs mode to generate logical position");
          width = parseModeWidth mode;
          scale = scaleOf o;
        in
        if width != null then round (width / scale) else throw "Output ${o.name} has invalid mode: ${mode}";
      normalizeOutputs =
        scaleOf: outputs:
        let
          step =
            state: output:
            let
              off = output.off or false;
              width = if off then null else logicalWidth scaleOf output;
              position =
                if output ? position && output.position != null then
                  output.position
                else if !off && width != null then
                  {
                    x = state.x;
                    y = 0;
                  }
                else
                  null;
              nextX = if !off && width != null && position != null then position.x + width else state.x;
            in
            {
              x = nextX;
              outputs = state.outputs ++ [ (output // { inherit position; }) ];
            };
        in
        (builtins.foldl' step {
          x = 0;
          outputs = [ ];
        } outputs).outputs;
      outputs = normalizeOutputs (o: o.scale or 1.0) rawOutputs;
      greeterOutputs = normalizeOutputs (_: greeterScale) rawOutputs;
      activeOutputs = builtins.filter (o: !(o.off or false) && (o.position or null) != null) outputs;
      activeGreeterOutputs = builtins.filter (
        o: !(o.off or false) && (o.position or null) != null
      ) greeterOutputs;
      greeterLayout = lib.concatStringsSep "; " (
        map (o: "${o.name}:${toString o.position.x},${toString o.position.y}") activeGreeterOutputs
      );
    in
    {
      nixos =
        {
          config,
          pkgs,
          user,
          ...
        }:
        let
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
            user.default = user.userName;
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

            greeter-args = "--session niri --user ${user.userName}";

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

          systemd.tmpfiles.settings."10-noctalia-greeter"."/var/lib/noctalia-greeter/greeter.toml".C = lib.mkForce {
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

          security.soteria.enable = true;

          environment.systemPackages = [ pkgs.xwayland-satellite ];
        };

      homeManager =
        {
          config,
          lib,
          ...
        }:
        let
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

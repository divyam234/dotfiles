{ inputs, den, ... }:
{
  den.aspects.dms = {
    includes = [ den.aspects.niri ];

    nixos = { pkgs, ... }: {
      # DMS is the shell/widgets layer for the Niri session.
      imports = [ inputs.dms.nixosModules.dank-material-shell ];

      programs.dank-material-shell = {
        enable = true;
        package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;

        enableDynamicTheming = true;
        enableSystemMonitoring = true;
        enableClipboardPaste = true;
        enableAudioWavelength = true;

        systemd = {
          enable = true;
          restartIfChanged = true;
        };
      };

      environment.systemPackages = with pkgs; [
        matugen
        libnotify
        wl-clipboard
        playerctl
        brightnessctl
      ];
    };

    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        matugen
        libnotify
        wl-clipboard
      ];
    };
  };
}

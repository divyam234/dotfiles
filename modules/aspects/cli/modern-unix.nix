{ den, ... }:
{
  den.aspects.modern-unix = {
    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = with pkgs; [
          chafa
          choose
          delta
          duf
          dust
          dysk
          eza
          fd
          fastfetch
          ffmpeg
          file
          gdb
          glow
          gomi
          grex
          gdu
          gum
          hexyl
          hyperfine
          imagemagick
          jnv
          jqp
          jq
          lm_sensors
          moreutils
          ncdu
          nh
          nix-output-monitor
          nvd
          ouch
          pciutils
          procs
          ripgrep
          sd
          systemctl-tui
          tailspin
          tealdeer
          tokei
          tree
          unzip
          usbutils
          viddy
          xxd
          yq-go
          zoxide
          zstd
        ];

        programs = {
          bat.enable = true;

          btop.enable = true;

          broot.enable = true;

          yazi = {
            enable = true;
            shellWrapperName = "yy";
          };
        };
      };
  };
}

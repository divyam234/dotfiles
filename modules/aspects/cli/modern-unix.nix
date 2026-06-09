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
          glow
          gomi
          grex
          gdu
          gum
          hexyl
          hyperfine
          jnv
          jqp
          jq
          moreutils
          nh
          nix-output-monitor
          nvd
          ouch
          procs
          ripgrep
          sd
          systemctl-tui
          tailspin
          tealdeer
          tokei
          unzip
          viddy
          yq-go
          zoxide
          zstd
        ];

        programs = {
          bat.enable = true;

          broot.enable = true;

          yazi = {
            enable = true;
            shellWrapperName = "yy";
          };
        };
      };
  };
}

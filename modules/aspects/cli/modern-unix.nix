
{ den, ... }:
{
  den.aspects.modern-unix = {
    homeManager = { pkgs, lib, ... }: {
      home.packages = with pkgs; [
        bat
        broot
        chafa
        choose
        delta
        duf
        dust
        dysk
        eza
        fd
        fzf
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
        tailspin
        tealdeer
        tokei
        unzip
        viddy
        yazi
        yq-go
        zoxide
        zstd
      ];
    };
  };
}

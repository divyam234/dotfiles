{ den, ... }:
{
  den.aspects.devtools = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          air
          autoconf
          automake
          bear
          bun
          cmake
          deadnix
          delve
          gcc
          go
          go-task
          golangci-lint
          golines
          goose
          gotestsum
          gnumake
          just
          libtool
          lsof
          marksman
          meson
          nil
          ninja
          nix-output-monitor
          nixd
          nixfmt
          nodejs_24
          pkgconf
          pnpm
          python3
          rust-bin.stable.latest.default
          shellcheck
          shfmt
          sqlc
          statix
          strace
          stylua
          taplo
          templ
          uv
          valgrind
          radare2
        ];
      };
  };
}

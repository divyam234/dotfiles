{ den, ... }:
{
  den.aspects.devtools = {
    homeManager =
      { pkgs, ... }:
      let
        moldStdenv = pkgs.stdenvAdapters.useMoldLinker pkgs.stdenv;
      in
      {
        home.packages = with pkgs; [
          android-tools
          actionlint
          air
          ast-grep
          autoconf
          automake
          bear
          bun
          cargo
          clippy
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
          jetbrains.jdk-no-jcef
          libtool
          lsof
          marksman
          meson
          mold
          nil
          ninja
          nix-output-monitor
          nixd
          nixfmt
          nodejs_24
          pkg-config
          pnpm
          python3
          rustc
          rustfmt
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
          qemu
          zig
        ];
        home.file.".cargo/config.toml".source = (pkgs.formats.toml { }).generate "cargo-config.toml" {
          target.${pkgs.stdenv.hostPlatform.rust.rustcTarget} = {
            linker = "${moldStdenv.cc}/bin/cc";
          };
        };
      };
  };
}

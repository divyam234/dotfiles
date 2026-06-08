{ den, ... }:
{
  den.aspects.devtools = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          air
          bun
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
          marksman
          nil
          nix-output-monitor
          nixd
          nixfmt
          nodejs_24
          pnpm
          python3
          rust-bin.stable.latest.default
          shellcheck
          shfmt
          sqlc
          statix
          stylua
          taplo
          templ
          uv
        ];
      };
  };
}

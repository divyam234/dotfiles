
{ den, ... }:
{
  den.aspects.devtools = {
    homeManager = { pkgs, ... }: {
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
        lua-language-server
        marksman
        nil
        nix-output-monitor
        nixd
        nixfmt-rfc-style
        nodejs_24
        pnpm
        python3
        rustup
        shellcheck
        shfmt
        sqlc
        statix
        stylua
        taplo
        templ
        typescript-language-server
        uv
        vscode-langservers-extracted
        yaml-language-server
      ];
    };
  };
}

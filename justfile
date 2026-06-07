
set dotenv-load := true

host := "homepc"
netcup := env_var_or_default("NETCUP_HOST", "root@NETCUP_IP")

fmt:
    nix fmt

check:
    nix flake check --show-trace

show:
    nix flake show

build h=host:
    nix build .#nixosConfigurations.{{h}}.config.system.build.toplevel --show-trace

switch h=host:
    sudo nixos-rebuild switch --flake .#{{h}} --show-trace

boot h=host:
    sudo nixos-rebuild boot --flake .#{{h}} --show-trace

home:
    home-manager switch --flake .#killer@homepc

deploy-netcup:
    nixos-rebuild switch --flake .#netcup --target-host {{netcup}} --build-host {{netcup}} --use-remote-sudo --show-trace

install-homepc disk:
    sudo nix run github:nix-community/disko -- --mode disko --flake .#homepc

svc +args:
    ./scripts/svc {{args}}

theme:
    ./scripts/theme-generate

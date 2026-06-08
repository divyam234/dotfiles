set dotenv-load

host := "laptop"
netcup := env("NETCUP_HOST", "root@NETCUP_IP")

fmt:
    nix fmt

check:
    nix flake check --show-trace

show:
    nix flake show

build h=host:
    nix build .#nixosConfigurations.{{ h }}.config.system.build.toplevel --show-trace

switch h=host:
    sudo nixos-rebuild switch --flake .#{{ h }} --show-trace

boot h=host:
    sudo nixos-rebuild boot --flake .#{{ h }} --show-trace

home u=host:
    home-manager switch --flake .#bhunter@{{ u }}

deploy h=host:
    nixos-rebuild switch --flake .#{{ h }} --target-host root@{{ ip }} --build-host root@{{ ip }} --use-remote-sudo --show-trace

deploy-netcup:
    nixos-rebuild switch --flake .#netcup --target-host {{ netcup }} --build-host {{ netcup }} --use-remote-sudo --show-trace

install-laptop disk:
    sudo nix run github:nix-community/disko -- --mode disko --flake .#laptop

svc +args:
    ./scripts/svc {{ args }}

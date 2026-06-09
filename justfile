set dotenv-load

host := "netcup"

fmt:
    nix fmt

check:
    nix flake check --show-trace

show:
    nix flake show

build h=host:
    nh os build .#{{ h }} --show-trace

switch h=host:
    nh os switch .#{{ h }} --show-trace

boot h=host:
    nh os boot .#{{ h }} --show-trace

home u=host:
    nh home switch .#bhunter@{{ u }} --show-trace

install-laptop disk:
    sudo nix run github:nix-community/disko -- --mode disko --flake .#laptop

svc +args:
    nix run .#svc -- {{ args }}

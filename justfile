set dotenv-load

host := "netcup"

fmt:
    nix fmt

check:
    nix flake check --show-trace

show:
    nix flake show

build h=host:
    nh os build . -H {{ h }}

test h=host:
    nh os test . -H {{ h }}

switch h=host:
    nh os switch . -H {{ h }}

boot h=host:
    nh os boot . -H {{ h }}

home u=host:
    nh home switch . -c bhunter@{{ u }}

svc +args:
    nix run .#svc -- {{ args }}

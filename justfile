set dotenv-load

host := "netcup"

fmt:
    nix fmt

fmt-check:
    git diff --check

check:
    nix flake check --show-trace

eval h=host:
    nix eval .#nixosConfigurations.{{ h }}.config.system.build.toplevel.drvPath

eval-all:
    just eval laptop
    just eval netcup

show:
    nix flake show

clean:
    nh clean all

update:
    nix flake update

commit-locked:
    nix flake update --commit-lock-file

build h=host:
    nh os build . -H {{ h }}

test h=host:
    nh os test . -H {{ h }}

switch h=host:
    nh os switch . -H {{ h }}

boot h=host:
    nh os boot . -H {{ h }}

home-standalone u="laptop":
    nh home switch . -c bhunter@{{ u }}

svc +args:
    nix run .#svc -- {{ args }}

svc-status:
    nix run .#svc -- stack status

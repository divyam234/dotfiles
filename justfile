set dotenv-load

host := "netcup"
nix_install_options := '--option experimental-features "nix-command flakes" --option extra-substituters "https://nix-community.cachix.org https://numtide.cachix.org" --option extra-trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="'

fmt:
    nix fmt

fmt-check:
    git diff --check

check:
    nix flake check --show-trace

eval h=host:
    nix eval .#nixosConfigurations.{{ h }}.config.system.build.toplevel.drvPath

eval-hm u="bhunter@laptop":
    nix eval .#homeConfigurations.{{ u }}.config.home.username

show:
    nix flake show

write-flake:
    nix run .#write-flake --show-trace

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

home u="bhunter@laptop":
    nh home switch . -c {{ u }}

disko h="homelab":
    sudo nix {{ nix_install_options }} run github:nix-community/disko -- --mode disko ./hosts/{{ h }}/disko.nix

install h="homelab":
    sudo nixos-install --flake .#{{ h }} {{ nix_install_options }}

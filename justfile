set dotenv-load

host := "laptop"

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

update-commit:
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

iso h=host:
    nix build .#{{ h }}-installer-iso

flash-iso device h=host:
    test -b "{{ device }}"
    test "$(lsblk -dn -o TYPE "{{ device }}")" = disk
    printf 'This will erase {{ device }}. Type ERASE to continue: '
    read confirmation
    test "$confirmation" = ERASE
    lsblk -nrpo MOUNTPOINTS "{{ device }}" | while IFS= read -r mountpoint; do test -z "$mountpoint" || sudo umount "$mountpoint"; done
    iso="$(nix build --print-out-paths .#{{ h }}-installer-iso)/iso/{{ h }}-installer.iso"; test -f "$iso"; sudo dd if="$iso" of="{{ device }}" bs=4M conv=fsync oflag=direct status=progress; sync

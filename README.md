# Dotfiles

NixOS and Home Manager configuration for two machines, built with flakes, flake-parts, and Den.

## Hosts

| Host | Platform | Configuration |
| --- | --- | --- |
| `laptop` | `x86_64-linux` | NixOS with standalone Home Manager (`bhunter@laptop`) |
| `netcup` | `aarch64-linux` | NixOS server with integrated Home Manager |

## Structure

```text
entity -> host aspect -> reusable aspects -> NixOS/Home Manager modules
```

- `modules/entities/` — host, home, and user declarations
- `hosts/` — hardware and host-specific configuration
- `modules/aspects/` — reusable roles, features, services, and application configuration
- `modules/core/` — Den schema and shared defaults
- `lib/` — helpers and evaluation checks
- `packages/svc/` — CLI and TUI for the Quadlet service stack

Host composition uses direct Den `includes`. Cross-aspect data is passed through quirks and checked for duplicate names during evaluation.

`flake.nix` is generated. Change `flake-file` declarations in the modules, then run:

```bash
just write-flake
```

## Commands

```bash
just fmt                     # format tracked Nix files
just check                   # run all flake checks
just eval laptop             # evaluate a NixOS host
just eval-hm                 # evaluate bhunter@laptop
just build netcup            # build without activating
just test netcup             # activate until reboot
just switch netcup           # build and activate
just home                    # switch bhunter@laptop Home Manager
just svc-status              # show hosted service status
cargo test --manifest-path packages/svc/Cargo.toml
```

The default NixOS host is `netcup`; the default Home Manager configuration is `bhunter@laptop`.

## Secrets

Secrets use SOPS and Age.

- Shared secrets: `secrets/common.yaml`
- Host secrets: `hosts/<name>/secrets.yaml`
- NixOS Age key: `/var/lib/sops-nix/key.txt`
- Home Manager Age key: `~/.config/sops/age/keys.txt`

Secret declarations are centralized in `lib/secrets.nix`. Service and feature modules consume the provided `secrets` argument instead of setting `sopsFile` directly.

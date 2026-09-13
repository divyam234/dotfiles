# Dotfiles

NixOS and Home Manager configuration for three machines, built with flakes, flake-parts, and Den.

## Hosts

| Host | Platform | Configuration |
| --- | --- | --- |
| `laptop` | `x86_64-linux` | NixOS with standalone Home Manager (`bhunter@laptop`) |
| `netcup` | `aarch64-linux` | NixOS server with integrated Home Manager |
| `homelab` | `x86_64-linux` | NixOS server with integrated Home Manager |

## Structure

```text
entity -> host aspect -> reusable aspects -> NixOS/Home Manager modules
```

- `modules/entities/` — data-only host, home, and user declarations
- `hosts/` — hardware and host-specific configuration
- `modules/aspects/` — reusable roles, features, services, and application configuration
- `modules/core/` — Den schema and shared defaults
- `lib/` — helpers and evaluation checks
- `packages/svc/` — CLI and TUI for the Quadlet service stack

Host composition uses direct Den `includes`. Feature-specific schema is declared beside each aspect, while cross-aspect data is passed through scope-local quirks and checked during evaluation. Den's built-in policies instantiate hosts and route integrated Home Manager users.

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
cargo test --manifest-path packages/svc/Cargo.toml
```

The default host for `just build/test/switch` is `laptop` (`host` parameter); the default Home Manager configuration is `bhunter@laptop`.

## Secrets

Secrets use SOPS and Age.

- Shared secrets: `secrets/common.yaml`
- Host secrets: `hosts/<name>/secrets.yaml`
- NixOS Age key: `/var/lib/sops-nix/key.txt`
- Home Manager Age key: `~/.config/sops/age/keys.txt`

The allowed secret catalog is centralized in `lib/secrets.nix`. Aspects emit `nixosSecrets` or `homeSecrets` quirks, so each configuration declares only the catalog entries it consumes. Service and feature modules use the provided `secrets` argument instead of setting `sopsFile` directly.

## Binary Cache

NixOS hosts run a loopback proxy for the signed cache published from
[divyam234/nix-cache](https://github.com/divyam234/nix-cache). The cache stores
raw NARs in immutable GitHub Release chunks and downloads reusable 32 MiB
blocks with validated HTTP range requests. Configuration and the trusted public
key live in `modules/aspects/system/nix.nix`.

## Container Deployments

OCI hosts expose a Tailscale-only webhook that lets an image-publishing GitHub
workflow queue Quadlet registry updates on every host. See
[`docs/container-updates.md`](docs/container-updates.md) for the tailnet policy
and workflow configuration.

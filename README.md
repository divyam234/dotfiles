# Dotfiles

Personal NixOS and Home Manager configurations, built with [Nix flakes](https://nixos.org/), [flake-parts](https://flake.parts/), and [Den](https://github.com/vic/den).

## Devices

| Host | Hardware | Platform | Role |
| --- | --- | --- | --- |
| [`laptop`](hosts/laptop/) | Intel Core i5-8300H, Intel + NVIDIA graphics | `x86_64-linux` | Workstation with MSI EC controls and Btrfs |
| [`ideapad`](hosts/ideapad/) | Intel Core i3-7100U, Intel + AMD graphics | `x86_64-linux` | Workstation with Intel media acceleration and rclone WebDAV |
| [`homelab`](hosts/homelab/) | AMD A6-7310 with Radeon R4 graphics | `x86_64-linux` | Home server with attached storage and a Librespot audio receiver |
| [`netcup`](hosts/netcup/) | ARM virtual machine | `aarch64-linux` | Service host with Caddy, PostgreSQL, Redis, backups, and a Tailscale exit node |
| [`capri`](hosts/capri/) | Motorola Moto G10 Power (XT2127-4), Qualcomm SM4250 | `aarch64-linux` | Native NixOS phone configuration with a custom kernel/U-Boot, TelDrive, and a Tailscale exit node |

All five hosts integrate Home Manager for `bhunter`.

The workstations share a Niri desktop with Noctalia, selected GNOME apps, Ghostty, and development tools. Display layouts are declared per host: `laptop` disables its internal panel and configures two 1080p/75 Hz HDMI outputs; `ideapad` configures its internal panel and one HDMI output at 1080p/60 Hz.

Capri has device-specific boot and firmware requirements; see its [hardware and bring-up notes](packages/capri/README.md) before building or installing it.

## Working with the configuration

Run commands from the repository root. Nix with flakes enabled and `just` are required; build and activation recipes use `nh`.

```bash
just eval laptop             # evaluate the system configuration
just eval-hm laptop          # evaluate the integrated Home Manager username
just build laptop            # build without activating
just test laptop             # activate without changing the boot default
just switch laptop           # build and activate permanently
just boot laptop             # make the configuration the next boot default
```

Host arguments default to the current hostname. `just home` is an alias for a system switch: Home Manager activates with NixOS, not separately. These recipes run locally; passing another hostname selects its configuration, not a remote deployment.

Before activating changes:

```bash
just fmt                     # format Nix files
just check                   # static checks, composition contracts, and host evaluations
```

`just check` evaluates `laptop`, `ideapad`, `homelab`, and `netcup`; evaluate `capri` explicitly with `just eval capri`.

To update pinned inputs, run `just update`, then evaluate and build the affected hosts before switching. These configurations contain machine-specific disks, networking, and user settings; review the target host before installing them elsewhere.

## Repository layout

| Path | Contents |
| --- | --- |
| [`hosts/`](hosts/) | Device declarations, host composition, hardware, storage, and networking |
| [`modules/entities/`](modules/entities/) | Home and user declarations |
| [`modules/aspects/`](modules/aspects/) | Reusable roles, desktop features, services, and application settings |
| [`modules/core/`](modules/core/) | Shared defaults, schemas, and injected arguments |
| [`lib/`](lib/) | Helpers, secret catalog, and evaluation-time contracts |
| [`packages/`](packages/) | Local tools and device support |
| [`secrets/`](secrets/) | Shared encrypted SOPS data |
| [`theme/`](theme/) | Shared visual assets |

Each host's `entity.nix` declares data; its `default.nix` selects reusable aspects through Den `includes`. Aspects provide NixOS and Home Manager modules. Shared service data, such as routes and secret requirements, flows through quirks and is checked during evaluation.

`flake.nix` is generated. Edit the source `flake-file` declarations in modules, then regenerate it:

```bash
just write-flake
```

## Local tools

- **[`dot`](packages/dot/README.md)** — configuration management CLI, including local builds and SSH-based deployment.
- **[`svc`](packages/svc/README.md)** — Rust CLI/TUI for inspecting and operating systemd-managed Quadlet containers.
- **[`camoflare`](packages/camoflare/README.md)** — browser-backed FlareSolverr-compatible service.

For `svc` development, run `cargo test --manifest-path packages/svc/Cargo.toml`.

## Secrets

Secrets are encrypted with SOPS and age. Never commit decrypted values or private keys.

| Item | Location |
| --- | --- |
| Shared secrets | `secrets/common.yaml` |
| Host secrets, where configured | `hosts/<name>/secrets.yaml` |
| NixOS age key | `/var/lib/sops-nix/key.txt` |
| Home Manager age key | `~/.config/sops/age/keys.txt` |

[`lib/secrets.nix`](lib/secrets.nix) defines the allowed catalog. Aspects request entries through `nixosSecrets` or `homeSecrets` and use the injected `secrets` argument for templates rather than setting `sopsFile` directly.

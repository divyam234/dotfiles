# Implemented pass

## Core

- Nixicle-style Den architecture.
- `flake-parts` + `import-tree` + `flake-file` bootstrap.
- Host inventory in `modules/hosts.nix`.
- Host aspects in `hosts/homepc/default.nix` and `hosts/netcup/default.nix`.
- No separate variable directory.
- Helper library under `lib/default.nix` for small repeated container/Caddy functions.
- `dot.caddy.global` and `dot.caddy.routes` option schema for service-owned Caddy routes.

## Hosts

- `homepc`: `x86_64-linux`, Btrfs/Disko, KDE Plasma 6, Matugen, Stylix, Fish, Zellij, dev tools, gaming, Podman, Ollama/Open-WebUI.
- `netcup`: `aarch64-linux`, generic networking placeholder, server profile, Podman OCI services, container Caddy, SOPS, Restic.

## OCI services

- Caddy container with `ghcr.io/tgdrive/caddy`.
- Generated Caddyfile from service-owned `dot.caddy.routes.*` declarations.
- Shared Podman network `svc`.
- Postgres container.
- Valkey container.
- Forgejo container.
- Atuin container.
- Attic server container.
- Vaultwarden container.
- Uptime Kuma container.
- Gotify container.
- Ollama/Open-WebUI containers for homepc.

## Secrets

- Host secret YAML stubs.
- SOPS templates for container env files under `/run/secrets/container-env`.
- Container paths centralized only in `lib/default.nix` helper constants, not a separate variable layer.

## Tools

- Fish shell with abbreviations/functions.
- Zellij copied from Nixicle with Asia/Kolkata timezone.
- Git with SSH signing defaults.
- SSH/GPG aspects.
- Neovim bootstrap.
- Modern Unix, dev, network, database and container tool aspects.
- Ghostty terminal aspect.

## Theming

- Stylix broad theme.
- Matugen config and templates.
- Bootstrap Base16 palette.
- KDE Plasma is the active desktop; Matugen generates the palette consumed by Stylix.


## Server development tools

Server hosts include `den.aspects.development`, so Netcup gets Fish, Git/SSH, Zellij, Neovim, Nix/Go/dev tooling, container tools, database clients, network tools, Attic client, and AI CLI tools. KDE/desktop/gaming apps remain homepc-only.

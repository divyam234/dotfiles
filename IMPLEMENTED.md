# Implemented pass

## Core

- Nixicle-style Den architecture.
- `flake-parts` + `import-tree` + `flake-file` bootstrap.
- Host inventory in `modules/hosts.nix`.
- Host aspects in `hosts/laptop/default.nix` and `hosts/netcup/default.nix`.
- No separate variable directory.
- Helper library under `lib/default.nix` for package imports and Caddy rendering.
- `dot.caddy.global` and `dot.caddy.routes` option schema for service-owned Caddy routes.
- `dot.containers.*` option schema for shared rootful Quadlet conventions.

## Hosts

- `laptop`: `x86_64-linux`, Btrfs/Disko, KDE Plasma 6, Matugen, Stylix, Fish, Zellij, dev tools, gaming, Podman, Ollama/Open-WebUI.
- `netcup`: `aarch64-linux`, generic networking placeholder, server profile, rootful Quadlet services, container Caddy, SOPS, Restic.

## Container services

- Caddy container with `ghcr.io/tgdrive/caddy`.
- Generated Caddyfile from service-owned `dot.caddy.routes.*` declarations.
- Shared Podman network `svc`.
- Persistent service data under `/home/bhunter/.local/state/container-services`.
- Per-service data directory ownership presets for container UIDs.
- Postgres container.
- Redis container.
- Forgejo container.
- Vaultwarden container.
- Siyuan container.
- Gluetun container with AdGuard CLI sharing its network namespace.
- Camofox, Databasus, and Hermes containers are available but manually started.

## Secrets

- Host secret YAML stubs.
- SOPS templates for container env files under `/run/secrets/container-env`.
- Container paths and ownership are centralized in `dot.containers` options, not host-local service internals.

## Tools

- Fish shell with abbreviations/functions.
- Zellij copied from Nixicle with Asia/Kolkata timezone.
- Git with SSH signing defaults.
- SSH/GPG aspects.
- Neovim bootstrap.
- Modern Unix, dev, network, database and container tool aspects.
- Ghostty terminal aspect.
- `svc` helper for rootful Quadlet service inspection.

## Theming

- Stylix broad theme.
- Matugen config and templates.
- Bootstrap Base16 palette.
- KDE Plasma is the active desktop; Matugen generates the palette consumed by Stylix.


## Server development tools

Server hosts include `den.aspects.development`, so Netcup gets Fish, Git/SSH, Zellij, Neovim, Nix/Go/dev tooling, container tools, database clients, network tools, Attic client, and AI CLI tools. KDE/desktop/gaming apps remain laptop-only.

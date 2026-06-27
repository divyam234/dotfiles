# Agent notes

## Architecture

```
inventory -> registry -> resolver/validator -> Den integration -> aspects
```

- `inventory/hosts.nix` — intent only: facts + directly requested services.
- `inventory/users.nix` — pure user data.
- `registry/default.nix` imports `services.nix` through `normalize.nix` (fills defaults).
- `lib/registry/resolve.nix` — pure transitive dep resolver + validator (secrets, domain, caddy checks).
- `modules/core/dispatch.nix` — calls resolver, maps resolved aspects into Den `includes`.
  Injects `host` into each aspect via `constantHandler`.

## Adding a service

1. Module under `modules/aspects/services/`. Must include `den.aspects.oci-service`.
2. Entry in `registry/services.nix` with `requires.services` (deps) and `requires.aspects`.
3. Add name to host's `services` list in `inventory/hosts.nix`.

No schema enums, dispatcher cases, aliases, or forwarding modules for service composition.
Service runtime deps (Quadlet `After`/`Requires`) stay in the service module; logical deps
go in `registry/services.nix`.

## Key quirk surfaces

- `caddyRoutes` — service aspects emit Caddy virtual host routes (merged by caddy aspect).
- `caddyLayer4Routes` — layer4 route snippets.
- `containerDataDirs` — persistent container data directories (created by `oci-base`).

## Secrets

`lib.denful.secrets` helpers instead of inline `sopsFile`. Shared: `secrets/common.yaml`.
Host-local: `hosts/<name>/secrets.yaml`. Age key at `/var/lib/sops-nix/key.txt`.

## Hosts

- **laptop** — x86_64, standalone HM (not NixOS). CachyOS LTS kernel. Intel UHD 630 + NVIDIA GTX 1050 (legacy 580, PRIME offload).
- **netcup** — aarch64, NixOS. Runs all 16 services.

Both use `tailscale.autoconnect`.

## Conventions

- `flake.nix` is auto-generated (`nix run .#write-flake`). Do not edit directly.
- Caddy must stay OCI container at `ghcr.io/tgdrive/caddy`.
- No KDE/Plasma, no GNOME Shell. Niri + Noctalia v5 + GNOME apps only.
- Do not reintroduce DMS, `compose.nix`, aliases, forwarding modules, or duplicate registration.
- Home PC: plain Btrfs, no encryption.

## Commands

```bash
just fmt                 # nix fmt
just check               # nix flake check --show-trace
just eval-all            # eval all host configs
just build netcup        # nh os build
just test netcup         # nh os test
just home bhunter@laptop # nh home switch
just svc-status          # nix run .#svc -- stack status
```

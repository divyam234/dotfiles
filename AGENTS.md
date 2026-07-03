# Agent notes

## Architecture

```text
entity -> same-named host aspect -> reusable aspects -> NixOS/Home Manager modules
                                      -> quirks -> single consumers
```

- `modules/entities/` contains direct host, home, and user declarations.
- `hosts/<name>/default.nix` defines the matching host aspect and imports host-specific files.
- `modules/aspects/` contains reusable roles, features, services, and application configuration.
- `modules/core/` contains the Den schema and shared defaults.
- `lib/checks/` contains evaluation-time composition checks.

Home Manager relationships are structural:

- `netcup` uses `integrated-home-manager`; user `bhunter` has the `homeManager` class.
- `laptop` has a classless system user and a standalone home named `bhunter@laptop`.

Do not add inventory conversion, mode flags, string routing, registries, dispatchers, dependency resolvers, or Den internal mutation.

## Change map

- Host declaration: `modules/entities/hosts/`
- Host implementation: `hosts/<name>/`
- Standalone home: `modules/entities/homes/`
- User data: `modules/entities/users/`
- Reusable behavior: `modules/aspects/`
- Host options and defaults: `modules/core/`
- Composition checks: `lib/checks/` and `modules/flake-outputs.nix`

Use `entityLib.mkNixos` and `entityLib.mkHome` from `modules/entities/defaults.nix`.

## Services

1. Add the service under `modules/aspects/services/`.
2. Keep the aspect limited to its modules and quirk payloads.
3. Select shared platform aspects once in the host aspect.
4. Keep Quadlet and systemd runtime dependencies in the service module.

Den `includes` are compositional, not identity-deduplicated. Do not repeat `oci-service`, `requires-domain`, or `requires-secrets` through every leaf service.

## Quirks and secrets

Shared quirk surfaces are `caddyRoutes`, `caddyLayer4Routes`, `containerDataDirs`, `postgresDatabases`, and `postgresSchemas`. Top-level names must be unique; consumers must fail on duplicates.

Use the provided `secrets` argument and the helpers from `lib.denful.secrets`.

- Secret contract: `lib/secrets.nix`
- Shared secrets: `secrets/common.yaml`
- Host secrets: `hosts/<name>/secrets.yaml`
- NixOS Age key: `/var/lib/sops-nix/key.txt`
- Home Manager Age key: `~/.config/sops/age/keys.txt`

Do not set `sopsFile` directly in feature or service modules.

## Invariants

- `flake.nix` is generated; run `just write-flake` instead of editing it.
- Do not access Den internals such as `__scopeHandlers`.
- Do not add inventory, registry, forwarding, or duplicate-registration layers.
- Caddy remains the `ghcr.io/tgdrive/caddy` OCI image.
- Desktop composition is Niri, Noctalia v5, and selected GNOME apps; no Plasma or GNOME Shell.
- Laptop storage remains plain Btrfs without encryption.
- Preserve existing uncommitted changes.

## Commands

```bash
just fmt                     # format tracked Nix files
just check                   # nix flake check --show-trace
just eval laptop             # evaluate a NixOS host
just eval-hm                 # evaluate bhunter@laptop
just build netcup            # build without activating
just test netcup             # activate until reboot
just switch netcup           # build and activate
just home                    # switch bhunter@laptop
just svc-status              # service stack status
cargo test --manifest-path packages/svc/Cargo.toml
```

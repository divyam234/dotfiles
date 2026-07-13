# Repository Guidelines

## Project Overview

This repository is the declarative NixOS and Home Manager configuration for:

- `laptop`: NixOS with standalone Home Manager for `bhunter@laptop`.
- `netcup` and other servers: NixOS with integrated Home Manager and OCI/Quadlet services.
- `packages/svc`: a Rust CLI/TUI for inspecting and operating systemd-managed Quadlet containers.

The flake uses flake-parts and Den to compose host entities, reusable aspects, and NixOS/Home Manager modules.

## Architecture & Data Flow

The composition path is:

```text
entity -> same-named host aspect -> reusable aspects -> NixOS/Home Manager modules
                                      -> quirks -> single consumers
```

- Host, home, and user entities live under `modules/entities/`. Constructors in `modules/entities/defaults.nix` create NixOS and Home Manager configurations.
- `hosts/<name>/default.nix` defines the host aspect and selects shared platform aspects once.
- Reusable behavior lives in `modules/aspects/`; aspects expose `den.aspects.<name>`, compose through `includes`, and provide `nixos` and/or `homeManager` functions.
- `modules/core/` defines Den defaults, schemas, shared arguments, and host options. Libraries and overlays are assembled in `lib/bootstrap.nix`.
- Cross-aspect data flows through the shared quirks `caddyRoutes`, `caddyLayer4Routes`, `containerDataDirs`, `postgresDatabases`, and `postgresSchemas`. Consumers must reject duplicate top-level names.
- Secrets flow from `lib/secrets.nix` and the injected `secrets` argument into SOPS declarations. Feature and service modules must not set `sopsFile` directly.
- Service aspects define Quadlet units and their systemd runtime dependencies. Do not duplicate `oci-service`, `requires-domain`, or `requires-secrets` through leaf services; Den `includes` are compositional, not identity-deduplicated.

Home Manager relationships are structural: `netcup` uses integrated Home Manager with a `homeManager`-class user; `bhunter@laptop` is a standalone home for a classless system user.

Do not introduce inventories, mode flags, string routing, registries, dispatchers, dependency resolvers, forwarding layers, or Den-internal mutation. Never access Den internals such as `__scopeHandlers`.

## Key Directories

- `modules/entities/`: direct host, home, and user declarations.
- `hosts/`: host-specific aspects, hardware, storage, networking, and secrets files.
- `modules/aspects/`: reusable roles, features, services, application configuration, and system behavior.
- `modules/core/`: Den schema, defaults, shared injections, and package policy.
- `lib/`: bootstrap helpers, secret contracts, Den helpers, and composition checks.
- `lib/checks/`: evaluation-time assertions for hosts, services, secrets, networking, and desktop composition.
- `packages/svc/`: Rust Quadlet service CLI/TUI plus its Nix package.
- `secrets/`: shared encrypted SOPS data; host-specific encrypted data remains under `hosts/<name>/`.
- `theme/`: shared visual assets/configuration.

## Development Commands

Run commands from the repository root, preferably inside the Nix development shell.

```bash
just fmt                      # format tracked Nix files with nixfmt
just fmt-check                # check whitespace errors in the diff
just check                    # flake eval, formatting, deadnix, statix, architecture/contracts
just eval laptop              # evaluate a NixOS host
just eval-hm                  # evaluate bhunter@laptop
just build netcup             # build a host without activating it
just test netcup              # activate until reboot
just switch netcup            # build and activate permanently
just boot netcup              # install as next boot configuration
just home                     # switch bhunter@laptop Home Manager config
just svc-status               # inspect the service stack
cargo test --manifest-path packages/svc/Cargo.toml
```

Other useful recipes: `just show`, `just iso <host>`, `just clean`, `just update`, and `just update-commit`. `just flash-iso` writes directly to a block device; treat it as destructive.

`flake.nix` is generated. Never edit it directly; change its source modules and run:

```bash
just write-flake
```

## Code Conventions & Common Patterns

### Nix

- Use `entityLib.mkNixos` and `entityLib.mkHome` from `modules/entities/defaults.nix`.
- Put direct declarations in `modules/entities/`, host implementation in `hosts/<name>/`, reusable behavior in `modules/aspects/`, and shared options/defaults in `modules/core/`.
- Name aspect files and `den.aspects.<name>` consistently. Compose existing aspects instead of creating a parallel convention.
- Use module options and `lib.mkIf` for reusable toggles. Enforce composition invariants with assertions and `lib/checks/` contracts.
- Use the injected `secrets` argument and `lib.denful.secrets` helpers. Shared secrets belong in `secrets/common.yaml`; host secrets belong in `hosts/<name>/secrets.yaml`.
- Preserve NixOS age key `/var/lib/sops-nix/key.txt` and Home Manager age key `~/.config/sops/age/keys.txt`.
- Keep Caddy on `ghcr.io/tgdrive/caddy`, desktop composition on Niri + Noctalia v5 + selected GNOME apps, and laptop storage on unencrypted Btrfs.

### Rust (`packages/svc`)

- Rust 2024 edition; dependencies are locked in `packages/svc/Cargo.lock`.
- Return `anyhow::Result`, add `Context` at process/I/O boundaries, and use `bail!` for invalid operations. Keep missing or unavailable runtime state explicit rather than panicking.
- `main.rs` parses the CLI, discovers Quadlets, refreshes systemd state, then dispatches output or operations.
- `quadlet.rs` parses `.container` files; `systemd.rs` batches `systemctl show`; `operations.rs` wraps `systemctl`, `podman`, and `journalctl`; `privilege.rs` selects/warmups sudo.
- TUI state is owned by `tui::App`. Long-running lifecycle actions use a worker thread plus an `mpsc` channel; prevent concurrent actions and restore the terminal through `TerminalSession` cleanup. The codebase does not use an async runtime.
- Keep human output and `--json` output separate; surface service query failures instead of silently dropping them.

## Important Files

- `flake.nix`: generated flake entry point; do not edit.
- `flake.lock`: pinned Nix input revisions.
- `justfile`: canonical development and deployment recipes.
- `modules/flake-outputs.nix`: formatter, dev shell, checks, eval outputs, and installer ISO packages.
- `modules/core/defaults.nix`: Den inputs, defaults, injections, quirks, and secret setup.
- `modules/core/schema.nix`: host and service option contracts.
- `modules/entities/defaults.nix`: NixOS/Home Manager constructors.
- `lib/bootstrap.nix`: extended library, overlays, Rust platform, and local packages.
- `lib/secrets.nix`: allowed secret paths and secret value contract.
- `lib/checks/default.nix`: composition-check aggregation.
- `packages/svc/src/main.rs`: `svc` command entry point.
- `packages/svc/default.nix`: Nix packaging and runtime PATH wrapping.

## Runtime/Tooling Preferences

- Nix flakes are the primary build/runtime interface; `flake.lock` pins inputs.
- Use `just` recipes and `nh` for NixOS/Home Manager builds and activation.
- Nix formatting is `nixfmt`; static checks are `deadnix` and `statix`. `nil` and `nixd` are available for editor/LSP support.
- Secrets use SOPS with age. Never commit decrypted secret material.
- Rust uses Cargo with the repository lockfile and the latest stable toolchain supplied by `rust-overlay`; the Nix package wraps `svc` with `podman` and `systemd` tools on `PATH`.
- There is no Node/Bun package workflow or repository CI workflow. Do not add JavaScript tooling for Nix or Rust tasks.

## Testing & QA

- Run `just check` after Nix changes. It evaluates host/home configurations and runs nixfmt, deadnix, statix, architecture guards, and composition contracts.
- Add evaluation-time behavior contracts under `lib/checks/` for generated NixOS/Home Manager state: exact services, ports, routes, secret names, output layouts, and similar observable invariants.
- Run `just eval <host>` or `just eval-hm` for focused configuration evaluation before a broader flake check.
- Rust tests are inline `#[cfg(test)]` modules in `packages/svc/src/`. Existing tests cover Quadlet parsing/discovery, systemd output parsing, privilege selection, and TUI state transitions.
- Run `cargo test --manifest-path packages/svc/Cargo.toml` after Rust changes. Use deterministic fixtures such as `tempfile`; test behavior and error states rather than source layout.
- Use `just test <host>` only when activation-until-reboot is appropriate. Build-only validation is `just build <host>`.
- No coverage threshold is configured. New tests should defend observable contracts and plausible regressions.

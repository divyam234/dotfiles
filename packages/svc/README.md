# svc

`svc` is a Quadlet-aware service CLI and Ratatui dashboard.

Services are discovered at runtime from `*.container` files in
`SVC_QUADLET_DIR` or `/etc/containers/systemd`. No service names or aliases are
compiled into the application. `ContainerName=` is honored for Podman commands,
with the Quadlet file name used as the fallback.

Service state is loaded with one batched `systemctl show` call per refresh.
Query failures remain visible in the CLI and dashboard instead of becoming a
silent unknown state.

## Usage

```text
svc                        # open the dashboard
svc list                   # human-readable service table
svc list --failed-only     # only failed/unavailable services
svc list --watch [SECS]    # reprint every SECS seconds (default 2)
svc --json list            # machine-readable service data
svc status forgejo
svc logs forgejo
svc start forgejo postgres
svc stop forgejo
svc restart forgejo
svc shell forgejo
svc exec forgejo -- ls /var/lib/postgresql
svc enable forgejo         # start at boot
svc disable forgejo
svc daemon-reload
svc pull forgejo
svc outdated               # registry status without changing anything
svc update --yes forgejo   # pull; if changed, stop, remove old image, start
svc stack status
```

Global flags: `--dry-run` prints mutating commands instead of running them,
`--timeout SECS` bounds each systemctl/podman call (default 120),
`--refresh-interval SECS` sets the dashboard tick (default 5, `SVC_REFRESH_INTERVAL`),
`-v`/`-vv` raise log verbosity (`SVC_LOG` overrides, e.g. `SVC_LOG=debug`).

Exit codes: `0` success, `1` error, `2` partial failure (multi-service action
with mixed results), outdated findings, or invalid CLI usage.

`svc update` stops services, so it asks for confirmation on a terminal and
requires `--yes` otherwise. Multi-service start/stop/restart/pull/enable/disable
attempt every target and print a summary instead of aborting on the first
failure.

Mutating commands elevate automatically. On NixOS, `svc` prefers
`/run/wrappers/bin/sudo`; elsewhere it falls back to `sudo` from `PATH`.
Set `SVC_NO_SUDO=1` to disable elevation (tests, rootless environments).

Dashboard keys:

```text
Tab / Shift-Tab move focus between services and logs
Up/Down or j/k  select service or scroll focused logs
PageUp/PageDown scroll logs by a page
Home/End        jump to top/bottom of logs
Mouse wheel     move selection or scroll focused logs
/               filter services (Enter keep, Esc clear)
s               start
x               stop (confirms)
r               restart (confirms)
U               update image (confirms)
P               pull image
!               open shell in container
space           pause/resume auto-refresh
R               refresh now
?               help overlay
q or Esc        quit (Esc first cancels confirm/filter)
```

The dashboard authenticates before entering raw terminal mode. Lifecycle
actions then run on a worker thread so rendering remains responsive. Logs
stream from a `journalctl -f` follower (capped at 2000 lines per service).
Terminal state is restored automatically when the dashboard exits or encounters
an error. `!` temporarily leaves the alternate screen so the shell runs in a
real terminal.

## Development

```text
cargo test --manifest-path packages/svc/Cargo.toml
cargo clippy --manifest-path packages/svc/Cargo.toml --all-targets -- -D warnings
cargo fmt --check
```

Unit tests cover Quadlet parsing/discovery, systemd output parsing, the update
state machine, privilege selection, CLI parsing, and TUI state transitions.
`tests/cli.rs` runs the built binary against stub `systemctl`/`podman`/`sudo`
scripts for end-to-end behavior (exit codes, dry-run, aggregation).

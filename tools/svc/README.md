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
svc                  # open the dashboard
svc list             # human-readable service table
svc --json list      # machine-readable service data
svc status forgejo
svc logs forgejo
svc start forgejo postgres
svc stop forgejo
svc restart forgejo
svc shell forgejo
svc pull forgejo
svc stack status
```

Mutating commands elevate automatically. On NixOS, `svc` prefers
`/run/wrappers/bin/sudo`; elsewhere it falls back to `sudo` from `PATH`.

Dashboard keys:

```text
Up/Down or j/k  select service
s               start
x               stop
r               restart
R               refresh
q or Esc        quit
```

The dashboard authenticates before entering raw terminal mode. Lifecycle
actions then run on a worker thread so rendering remains responsive. Terminal
state is restored automatically when the dashboard exits or encounters an
error.

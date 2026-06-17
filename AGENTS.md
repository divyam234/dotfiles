# Agent notes

- Hosts contain intent only: one role, directly requested features, directly requested services, metadata.
- Registry owns names and dependency metadata for roles, features, and services.
- The resolver is the only name-to-aspect dispatch path.
- Schema enums are generated from registry keys.
- Service modules do not select other application or infrastructure services.
- Service runtime dependencies remain local in Quadlet/systemd ordering.
- Application containers use rootful `virtualisation.quadlet` with Podman.
- Caddy must remain an OCI container using `ghcr.io/tgdrive/caddy`.
- Noctalia is the desktop shell; do not reintroduce DMS.
- Do not introduce compatibility aliases, forwarding modules, adapters, or duplicate registration sites.
- Do not reintroduce a giant host-local compose.nix.
- Home PC uses plain Btrfs without encryption; `/persist` exists for later persistence experiments but is not enabled by default.

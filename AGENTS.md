# Agent notes

- Keep the repository Nixicle-style: hosts only choose Den aspects; aspects own real config.
- Do not reintroduce a giant host-local compose.nix.
- App services run via rootful virtualisation.quadlet using Podman.
- Caddy must remain an OCI container using ghcr.io/tgdrive/caddy.
- Home PC uses plain Btrfs without encryption; /persist exists for later persistence experiments but is not enabled by default.

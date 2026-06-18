# Dotfiles

Den-based NixOS dotfiles for a workstation and an ARM server.

The architecture is intentionally linear:

```text
inventory -> registry -> resolver/validator -> thin Den integration -> aspects
```

Hosts contain intent only. Aspects own implementation.

## Terms

- **Role**: one broad host purpose, such as `workstation` or `server`.
- **Feature**: a selectable machine capability, such as `desktop`, `gaming`, `containers`, `tailscale`, `firewall`, or a security policy.
- **Service**: a hosted application or infrastructure component, such as Forgejo, Caddy, PostgreSQL, PgDog, Redis, Vaultwarden, SiYuan, or AdGuard.
- **Primitive**: a non-user-selectable implementation building block, such as `oci-base`, `container-network`, or `container-secrets`.

## Layout

- `inventory/users.nix`: pure user data.
- `inventory/hosts.nix`: pure host intent.
- `registry/roles.nix`: roles and their default features.
- `registry/features.nix`: feature metadata and feature dependencies.
- `registry/services.nix`: service metadata and service dependencies.
- `lib/registry/resolve.nix`: pure dependency resolver and validator.
- `modules/core/`: Den schema, entity creation, and dispatch.
- `modules/aspects/`: implementation aspects.

## Adding a host

1. Add pure host data to `inventory/hosts.nix`.
2. Choose exactly one `role`.
3. Add only directly requested `features`.
4. Add only directly requested `services`.
5. Add `domain` and `secretsFile` only when required by resolved services.
6. Keep host-local files under `hosts/<name>/` hardware/networking focused.

## Adding a role

1. Add one entry to `registry/roles.nix`.
2. List default features for that role.
3. List supported systems.
4. Do not include implementation aspects in the role registry.

## Adding a feature

1. Add one implementation aspect under `modules/aspects/`.
2. Add one entry to `registry/features.nix`.
3. Set `requires`, `conflicts`, or `supportedSystems` only when needed.

## Adding a service

Adding a service requires exactly:

1. one service implementation module under `modules/aspects/services/`;
2. one entry in `registry/services.nix`.

Enabling it on a host requires:

3. adding its name to that host's `services` list in `inventory/hosts.nix`.

Do not add schema enums, dispatcher cases, service maps, group modules, aliases, or forwarding modules.

## Adding a service dependency

Add it only in `registry/services.nix`:

```nix
forgejo.requires.services = [ "caddy" "pgdog" ];
```

Service modules may keep runtime ordering such as Quadlet `After` and `Requires`, but they must not include other application or infrastructure service aspects.

## Inspecting resolved plans

```bash
nix eval --json .#resolvedHosts.laptop
nix eval --json .#resolvedHosts.netcup
```

The output shows requested features/services and resolved transitive dependencies.

## Validation

```bash
nix fmt
git diff --check
deadnix .
statix check .
nix flake check --show-trace
just eval-all
```

## Containers

Application services run as rootful system Quadlets through Podman.

- Caddy remains an OCI container using `ghcr.io/tgdrive/caddy`.
- Shared Podman network: `svc`.
- Runtime secret env directory: `/run/secrets/container-env`.
- Persistent data root: `/home/<user>/.local/state/container-services`.
- Service container images use their provided tags/references and opt into Podman `autoUpdate = "registry"`.

## Backups and restore

Restic backup names are host-derived: `services.restic.backups.${host.hostName}`.

Backups include the container data root and a PostgreSQL dump generated before backup when the PostgreSQL container exists.

Restore outline:

1. Restore Restic data to a temporary directory.
2. Stop affected Quadlet services.
3. Restore service data directories under `/home/<user>/.local/state/container-services`.
4. For PostgreSQL, restore from the dump with `psql`/`pg_restore` into a fresh container instead of relying only on copied live data files.
5. Start dependencies first, then application services.

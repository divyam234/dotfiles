# Dotfiles

Den-based NixOS dotfiles for a workstation and an ARM server.

This repository is organized around one rule: **hosts declare intent, aspects own implementation**. A host should say what it is and what it needs. It should not contain a local pile of NixOS service configuration or a Docker Compose replacement.

## Systems

- `laptop`: x86_64 NixOS workstation with Btrfs, desktop apps, gaming, development tools, Tailscale, and Podman support.
- `netcup`: aarch64 NixOS server with Podman-backed application services behind a Caddy container.

## Mental Model

Den separates the repo into data and behavior.

**Entities** declare what exists.

Examples: users, hosts, standalone homes.

**Host data** declares what a machine should be.

Each host has a role, optional features, optional services, domain metadata, and a host secrets file.

**Policies** translate host data into aspects.

The host dispatch policy maps `role`, `features`, and enabled `services` to the aspect graph.

**Aspects** own real configuration.

Roles, features, desktop pieces, system primitives, OCI primitives, and service catalog entries are aspects. Hosts do not configure those internals directly.

**Libraries** provide small rendering/building helpers.

The helper layer is intentionally small: package import helpers, Caddy rendering helpers, and bootstrap glue.

## Architecture

The repo is split by responsibility:

- Bootstrap modules define schema, Nixpkgs overlays, Home Manager integration, default includes, and instantiation behavior.
- Entity modules define users, hosts, and standalone homes.
- Policy modules translate host data into aspect includes.
- Role aspects describe broad machine classes such as workstation and server.
- Feature aspects describe optional capability bundles such as desktop, development, gaming, containers, and Tailscale.
- Service catalog aspects describe applications such as Caddy, Forgejo, Vaultwarden, Postgres, Redis, and Hermes.
- Primitive aspects hold low-level reusable building blocks such as Podman, container networking, and container secret templates.
- Host-local modules are hardware-only: disk layout, generated hardware configuration, networking details, and state version.

The expected flow is:

```text
host entity data
  -> schema validation
  -> host dispatch policy
  -> role, feature, and service aspects
  -> NixOS and Home Manager configurations
```

## Host Data

A host should read like an inventory record, not an implementation file.

Example shape:

```nix
den.hosts.x86_64-linux.laptop = {
  users.bhunter = dotUsers.bhunter;
  role = "workstation";
  features = [
    "btrfs"
    "containers"
    "gaming"
    "tailscale"
  ];
};
```

Server services use a typed service catalog:

```nix
den.hosts.aarch64-linux.netcup = {
  users.bhunter = dotUsers.bhunter;
  role = "server";
  features = [
    "containers"
    "tailscale"
  ];
  services = {
    caddy.enable = true;
    postgres.enable = true;
    forgejo.enable = true;
    vaultwarden.enable = true;
  };
  domain = "example.com";
  secretsFile = ../../hosts/netcup/secrets.yaml;
};
```

Prefer typed service flags over string lists. Typos in service names should fail at evaluation time.

## Adding A Host

1. Add a host entity with a `role`.
2. Attach users from the shared user inventory.
3. Add feature names only for optional capabilities.
4. Enable service catalog entries only for application services that should run on that host.
5. Add a host secrets file if any enabled service needs SOPS material.
6. Keep the host-local NixOS module hardware-focused: hardware configuration, disk layout, networking, and state version only.
7. Run `just check`.

Do not add a giant host-local compose file or a host-local list of service internals.

## Adding A Feature

Use a feature when the host wants a capability, not a single application service.

Good feature examples:

- desktop environment baseline
- development toolchain
- gaming support
- container runtime support
- Tailscale support

After adding a feature aspect, register it in host dispatch so hosts can enable it through `features = [ ... ]`.

## Adding A Service

Use a service catalog aspect for an application service.

To add a service:

1. Add the service to the typed service catalog schema.
2. Add the service aspect.
3. Register the service in host dispatch.
4. Enable it on the target host with `services.<name>.enable = true;`.
5. If it needs secrets, read them from `host.secretsFile`.

The service aspect should own:

- container image
- volumes
- environment files
- service dependencies
- Caddy route, if public
- service-specific systemd overrides

The service aspect should not require host files to know how it works. A host should only enable it:

```nix
services.forgejo.enable = true;
```

If the service needs secrets, consume `host.secretsFile`. Do not hardcode one host's secrets file inside the service.

## Containers

Application services run through rootful NixOS `virtualisation.quadlet` with Podman as the backend.

Shared conventions:

- persistent service data root: `/home/bhunter/.local/state/container-services`
- runtime secret env files: `/run/secrets/container-env`
- shared Podman network: `svc`

Services should use the shared `dot.containers` options instead of hand-writing repeated systemd/network boilerplate.

## Caddy

Caddy is an OCI container and must stay that way.

Image:

```text
ghcr.io/tgdrive/caddy
```

Public routes are collected from service aspects and rendered into a generated Caddyfile. A service that exposes HTTP owns its own route data.

Example:

```nix
dot.caddy.routes.forgejo = {
  host = "git.${host.domain}";
  upstreams = [ "forgejo:3000" ];
  cacheStatic = true;
};
```

## Secrets

SOPS is the source of service secrets.

Hosts that enable secret-backed services must set `secretsFile`. Service aspects read from that host-level file.

This keeps services reusable: the Forgejo aspect should not know which physical machine currently runs it.

## Commands

Enter the development shell:

```bash
nix develop
```

Format and validate:

```bash
just fmt
just check
```

Inspect outputs:

```bash
just show
```

Build or switch a host:

```bash
just build laptop
just switch laptop
```

Deploy the server:

```bash
NETCUP_HOST=root@host.example just deploy-netcup
```

Inspect a container service:

```bash
just svc status caddy
just svc logs forgejo
```

# Killer Crock dotfiles

Nixicle-style Den/NixOS dotfiles for two machines:

- `homepc` — `x86_64-linux`, NixOS desktop, Btrfs, KDE Plasma 6, Matugen, Stylix.
- `netcup` — `aarch64-linux`, NixOS ARM server, Podman OCI services.

## Architecture

```text
flake.nix
  -> flake-parts
  -> import-tree ./modules
  -> Den aspects
  -> hosts/homepc + hosts/netcup
```

This repo intentionally does **not** use a separate variable layer. It follows the Nixicle-style layout:

```text
modules/hosts.nix        user and host inventory
hosts/*/default.nix      host aspect composition
modules/aspects/*        feature/service/tool aspects
lib/default.nix          small reusable helpers only
```

Services are not Docker Compose files. They are Den aspects that use:

```nix
virtualisation.oci-containers.containers.<name>
```

Caddy is intentionally an OCI container using:

```text
ghcr.io/tgdrive/caddy
```

## First edit checklist

1. Replace `CHANGE_ME_killer_public_key` in `modules/hosts.nix`.
2. Replace `CHANGE_ME_HOMEPC_DISK` in `hosts/homepc/disko.nix` before using Disko.
3. Replace host hardware configs with real generated files.
4. Configure `.sops.yaml`, then encrypt `hosts/*/secrets.yaml`.
5. Replace placeholder `domain = "example.com"` / `domain = "home.example.com"` in `modules/hosts.nix`.
6. Replace `theme/wallpaper.png`, run `just theme`.

## Commands

```bash
nix develop
just check
just build homepc
just switch homepc
just deploy-netcup
just svc status caddy
just svc logs forgejo
```

## Service layout

Persistent container data lives under:

```text
/var/lib/killer-containers/<service>
```

Shared Podman network:

```text
svc
```

Runtime env files from SOPS templates:

```text
/run/secrets/container-env/<service>.env
```

## Caddy route pattern

Caddy is generated from a merged option set, not a central hand-written route list. Each service aspect owns its own public route:

```nix
dot.caddy.routes.forgejo = {
  host = "git.${host.domain}";
  upstreams = [ "forgejo:3000" ];
  cacheStatic = true;
};
```

The Caddy container aspect renders all `dot.caddy.routes.*` into `/etc/caddy/Caddyfile` and runs `ghcr.io/tgdrive/caddy`.


## Server development tools

Server hosts include `den.aspects.development`, so Netcup gets Fish, Git/SSH, Zellij, Neovim, Nix/Go/dev tooling, container tools, database clients, network tools, Attic client, and AI CLI tools. KDE/desktop/gaming apps remain homepc-only.

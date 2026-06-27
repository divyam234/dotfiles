# Dotfiles

Den-based NixOS dotfiles for a workstation and an ARM server.

The architecture is intentionally linear:

```text
inventory -> service registry/resolver -> thin Den integration -> aspects
```

Hosts contain facts and directly requested hosted services. Den aspects own host
composition and implementation.

The service registry is metadata, not another module layer. The resolver expands
service dependencies, validates the result, and returns one ordered
`resolvedAspects` list for service-required aspects. The Den dispatch layer stays
intentionally dumb: it includes the resolved service aspects and does not inspect
registry internals.
Host-to-user Home Manager projection uses Den's `host-aspects` battery instead
of a custom user `provides` tree.

## Terms

- **Role aspect**: a Den aspect bundle, such as `workstation` or `server`.
- **Aspect**: a Den composition unit, such as `desktop`, `btrfs`, `oci-runtime`, `tailscale`, `firewall`, or a security policy.
- **Service**: a hosted application or infrastructure component, such as Forgejo, Caddy, PostgreSQL, PgDog, Redis, Vaultwarden, SiYuan, or AdGuard.
- **Primitive**: a non-user-selectable implementation building block, such as `oci-base`, `container-network`, or `container-secrets`.

## Layout

- `inventory/users.nix`: pure user data.
- `inventory/hosts.nix`: host facts and directly requested services.
- `registry/services.nix`: service metadata, dependencies, and required aspects.
- `lib/registry/resolve.nix`: pure dependency resolver, validator, and name-to-aspect mapper.
- `modules/core/`: Den schema, entity creation, and dispatch.
- `modules/aspects/`: implementation aspects.

## Desktop stack

The workstation is a focused Wayland setup rather than a full desktop environment:

- **Niri** owns windows, workspaces, inputs, outputs, screenshots, and compositor keybindings.
- **Noctalia v5** owns the bar, launcher, control center, wallpaper, notifications, OSDs, lock screen, and session menu.
- **Noctalia Greeter** owns the greetd login screen and defaults to the Niri session.
- **GTK/GNOME infrastructure** provides portals, secrets, removable-drive support, file pickers, and application theming.
- **GNOME applications only** provide Files (Nautilus), Loupe, Evince, File Roller, Text Editor, and Calculator. GNOME Shell is not installed.
- **No KDE/Plasma stack** is enabled or installed by the desktop aspects.

Important bindings:

- `Super+Enter`: Ghostty
- `Super+B`: Brave
- `Super+E`: Nautilus
- `Super+S`: Text Editor
- `Super+Space`: Noctalia launcher
- `Super+Shift+Space`: Noctalia control center
- `Super+Ctrl+Space`: Noctalia session menu
- `Super+Alt+L`: lock screen
- `Super+O`: Niri overview

Noctalia's declarative config establishes a Stylix-derived dark palette and enables GTK/Qt template generation. Settings changed in the Noctalia UI remain writable under `~/.local/state/noctalia/` and override the Nix-managed defaults. Use Noctalia Settings → Shell → Security → Noctalia Greeter → Sync Now to copy the current wallpaper, palette, and monitor layout to the greetd greeter.

The Niri config pins the laptop dock layout to two 1080p external displays at 1.25 scale and disables the internal panel. Noctalia Greeter uses connector names for static output configuration, so sync it from Noctalia Shell after first login or inspect `noctalia-greeter outputs` before adding a greeter-local `output_layout`.

## Laptop graphics and kernel

The laptop configuration is derived from `hosts/laptop/facter.json`:

- Intel UHD 630 (`0000:00:02.0`) drives Niri and is the default VAAPI device through the `iHD` media driver.
- NVIDIA GTX 1050 Mobile (`0000:01:00.0`, Pascal) uses the proprietary NVIDIA 580 legacy branch.
- PRIME offload keeps normal desktop work on Intel. Prefix demanding applications with `nvidia-offload`.
- The kernel is CachyOS LTS, optimized for `x86-64-v3`, from the CI-tested `nix-cachyos-kernel/release` input.

Useful checks after switching:

```bash
vainfo
nvidia-smi
nvidia-offload glxinfo -B
nvidia-offload vulkaninfo --summary
intel_gpu_top
nvtop
```

For media applications, prefer Intel VAAPI for efficient everyday playback. Use NVIDIA's native NVDEC/NVENC paths for explicit GPU work, for example:

```bash
mpv --hwdec=vaapi video.mkv
nvidia-offload mpv --hwdec=nvdec video.mkv
nvidia-offload ffmpeg -hwaccel cuda -i input.mkv -c:v h264_nvenc output.mkv
```

The NVIDIA VAAPI bridge is also installed for applications that specifically require VAAPI. Select it explicitly rather than globally so opening a browser does not wake the discrete GPU:

```bash
env LIBVA_DRIVER_NAME=nvidia NVD_BACKEND=direct \
  vainfo --display drm --device /dev/dri/by-path/pci-0000:01:00.0-render
```

## Brave policy

Brave is the default browser. A managed policy under `/etc/brave/policies/managed/` disables Rewards/ads, Wallet/web3, VPN, Leo AI, News, Talk, Playlist, Tor, telemetry, promotional tabs, background mode, and the sponsored new-tab surface. Inspect the active policy at `brave://policy`.

## Adding a host

1. Add pure host data to `inventory/hosts.nix`.
2. Add host composition as Den `includes` in `hosts/<name>/default.nix`.
3. Add only directly requested `services` to inventory.
4. Add `domain` and `secretsFile` only when required by host-local secrets or resolved services.
5. Keep host-local files under `hosts/<name>/` hardware/networking focused.

## Secrets

SOPS files are selected through `lib.denful.secrets` helpers instead of inline `sopsFile` paths.

- Shared secrets live in `secrets/common.yaml` and use `lib.denful.secrets.common`.
- Host/service-local secrets live in `hosts/<name>/secrets.yaml` and use `lib.denful.secrets.host`.
- The user password key is `users/<username>/password`, for example `users/bhunter/password`.
- The install still copies only the age key to `/var/lib/sops-nix/key.txt`; encrypted YAML files remain in the dotfiles checkout.

## Adding An Aspect Bundle

Add a Den aspect under `modules/aspects/` and compose it with `includes`. Do not
add registries, schema enums, dispatch cases, aliases, or forwarding modules for
ordinary aspect composition.

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

When a service needs a non-service runtime aspect, add it as service metadata:

```nix
forgejo.requires.aspects = [ "oci-runtime" ];
```

## Inspecting resolved plans

```bash
nix eval --json .#resolvedHosts.laptop
nix eval --json .#resolvedHosts.netcup
```

The output shows requested services, resolved transitive services, and service-required aspects.

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

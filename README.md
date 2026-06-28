# Dotfiles

Two hosts: **laptop** (x86_64, standalone Home Manager) and **netcup** (aarch64 NixOS with integrated Home Manager).

```text
Den entity modules -> same-named host aspects -> feature/service includes -> class modules
                                                   -> quirks -> single consumers
```

Hosts, users, and standalone homes are declared directly under `modules/entities/`. There is no
inventory conversion layer and no Home Manager mode flag. The relationship is structural:

- `netcup` includes the integrated Home Manager aspect and owns user `bhunter` with the `homeManager` class.
- `laptop` owns a classless system user, while `bhunter@laptop` is declared as a standalone `den.home`.

Each host has a same-named aspect that selects its roles, features, shared platform aspects, and
services through direct `includes`. Shared platform aspects are selected once per host because
repeated Den includes are compositional, not identity-deduplicated. Quadlet and systemd runtime
ordering stays in the service modules.

Cross-aspect data uses Den quirks:

- `caddyRoutes` and `caddyLayer4Routes` are rendered once by the Caddy aspect.
- `containerDataDirs` is consumed once by the OCI base aspect.
- Duplicate route and directory names fail evaluation instead of being silently overwritten.

Repository layout:

- `modules/entities/` — direct host, home, and user declarations plus shared constructors
- `hosts/` — host-specific hardware/configuration files and same-named Den host aspects
- `modules/core/` — Den schema, defaults, quirks, and class defaults
- `modules/aspects/` — roles, features, primitives, Home Manager integration, and services
- `lib/` — shared Nix helpers

There is no service registry, dependency resolver, dispatcher, inventory layer, or mode-based Home
Manager routing. Adding a service means creating its aspect and selecting it, plus any required
shared platform aspects, from a host aspect.

# Dotfiles

Two hosts: **laptop** (x86_64, standalone HM) and **netcup** (aarch64, NixOS).

```
inventory -> registry -> resolver/validator -> Den integration -> aspects
```

Hosts contain intent only (facts + directly requested services). Registry owns
names and dependency metadata for services. The resolver is the only name-to-aspect
dispatch path — it expands transitive deps, validates, and returns resolved aspects.
Den aspects own composition and implementation.

- `inventory/` — pure user and host data
- `registry/` — service metadata, dependencies, required aspects
- `lib/registry/` — resolver, validator, normalizer
- `modules/core/` — Den schema, entities, dispatch
- `modules/aspects/` — all implementations

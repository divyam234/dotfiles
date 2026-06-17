# Implemented architecture

This repository now follows:

```text
inventory -> registry -> resolver/validator -> Den integration -> aspects
```

- Pure user and host inventory lives in `inventory/`.
- Role, feature, and service metadata lives in `registry/`.
- The resolver in `lib/registry/` computes transitive service and feature dependencies.
- `modules/core/` turns resolved plans into Den aspect includes.
- Implementation remains in `modules/aspects/`.

Hosts list only intent. Service dependencies are registered once in `registry/services.nix`.

# camoflare

FlareSolverr-compatible cookie minter backed by the Camofox browser
server. `POST /v1` accepts the FlareSolverr commands (`sessions.create`,
`sessions.list`, `sessions.destroy`, `request.get`, `request.post`) and
drives Camofox tabs underneath — but the solution carries **cookies
only** (`url`, `cookies`, `userAgent`). No HTML, no headers, no
screenshots: rendering and fetching are client-side (e.g. over a
TLS-impersonating transport with the minted cookies).

Listens on `:8191` by default — the FlareSolverr port — making it a
drop-in replacement.

## Configuration (environment)

| Variable              | Default                 | Purpose                                            |
| --------------------- | ----------------------- | -------------------------------------------------- |
| `CAMOFLARE_LISTEN`    | `:8191`                 | Listen address                                     |
| `CAMOFOX_URL`         | `http://localhost:9377` | Camofox server base URL                            |
| `CAMOFOX_ACCESS_KEY`  | —                       | Bearer for Camofox routes (when the server sets it) |
| `CAMOFOX_API_KEY`     | —                       | Bearer for Camofox cookie import (required if clients send `cookies`) |
| `CAMOFLARE_SESSION_KEY` | `flaresolverr`        | Camofox tab-group key for session tabs             |

## Behavior notes

- Session ids map 1:1 onto Camofox browser contexts (`userId`), so
  cookies and storage stay isolated per session.
- `request.get` without a session uses an ephemeral context that is
  destroyed after the solve.
- Challenge detection looks for Cloudflare / DDoS-GUARD interstitial
  markers (`Just a moment`, `__cf_chl`, verification copy). A page that
  merely mentions Cloudflare is not flagged.
- `returnScreenshot` is rejected: camoflare returns cookies only.
- `solution.headers` is synthesized (`content-type: text/html`); the
  browser DOM does not expose origin response headers.
- `solution.cookies` come from the `storage_state` export when the Camofox
  VNC plugin is enabled (`ENABLE_VNC=1`), with full fidelity (domain,
  path, expiry, httpOnly, secure). Without it, they fall back to
  `document.cookie` synthesis, which cannot see HttpOnly cookies such as
  `cf_clearance`. Replay them with the returned `userAgent`, or
  clearance will re-trigger — same rule as upstream FlareSolverr.
- The `proxy` request knob is accepted and ignored: Camofox routes all
  traffic through its server-global proxy configuration.
- `GET /health` reports shim liveness plus Camofox reachability.

## Development

```bash
go test ./...
go vet ./...
```

The package is stdlib-only, so no vendoring is needed. The Nix package
(`default.nix`) stamps `main.version` from its own `version` via ldflags.

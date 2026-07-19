# Triggering Container Updates from GitHub Actions

Every host composed with `den.aspects.oci-service` runs a webhook at:

```text
http://<tailscale-hostname>:9080/hooks/container-update
```

The endpoint is reachable only over Tailscale and queues the host's
`podman-auto-update.service`. Podman checks running Quadlet containers with
`AutoUpdate=registry`, pulls changed image digests, and restarts only the units
whose images changed.

The same updater also runs daily with up to one hour of randomized delay. This
scheduled fallback updates third-party images that do not have a publishing
workflow and catches missed webhook deliveries. Persistent timer state causes a
missed check to run after an offline host starts again.

The listener cannot accept command names or arguments. Its systemd sandbox also
denies connections outside Tailscale's IPv4 and IPv6 ranges. Port `9080` is not
opened in the public firewall.

## Tailnet Policy

Create a `tag:github-deploy` identity for GitHub Actions and grant it access only
to the webhook port on NixOS servers:

```json
{
  "tagOwners": {
    "tag:github-deploy": ["autogroup:admin"]
  },
  "grants": [
    {
      "src": ["tag:github-deploy"],
      "dst": ["tag:nixos"],
      "ip": ["tcp:9080"]
    }
  ]
}
```

Merge these entries into the existing tailnet policy rather than replacing its
other owners or grants.

Create a Tailscale OAuth client with the `auth_keys` scope and permission to
issue `tag:github-deploy`. Store its secret as the `TS_OAUTH_CLIENT_SECRET`
GitHub Actions secret in the image repository. Prefer a dedicated deployment
client instead of reusing a server credential that can issue `tag:nixos`.

## Publishing Workflow

Add a deployment job after the image-publishing job. The runner joins the
tailnet once, then calls every container host. Hosts that do not run the changed
image perform a check but restart nothing.

```yaml
permissions:
  contents: read

jobs:
  publish:
    # Existing image build and push steps.

  deploy:
    needs: publish
    runs-on: ubuntu-latest
    steps:
      - name: Join tailnet
        uses: tailscale/github-action@v4
        with:
          authkey: "${{ secrets.TS_OAUTH_CLIENT_SECRET }}?ephemeral=true&preauthorized=true"
          args: --advertise-tags=tag:github-deploy
          ping: homelab,netcup

      - name: Queue container updates
        run: |
          failed=0
          for host in homelab netcup; do
            curl --fail-with-body \
              --retry 3 \
              --retry-all-errors \
              --request POST \
              "http://$host:9080/hooks/container-update" || failed=1
          done
          exit "$failed"

      - name: Leave tailnet
        if: always()
        run: sudo -E tailscale logout
```

The update step attempts every host before reporting failure. The final step
runs even when joining the tailnet or updating a host fails. Logging out removes
the ephemeral device immediately; the action also registers its own post-job
logout as a fallback. If the runner terminates before either cleanup executes,
Tailscale automatically removes the inactive ephemeral device after roughly
30-60 minutes.

Delete any stale devices left by older, non-ephemeral workflow runs once from
the Tailscale Machines page. New runs should not require manual deletion.

# Proxy Net Ownership Swap (dashboards-automation -> infrastructure-networking)

**Status: repo changes prepared, host cutover not yet applied.** The compose
edits, `CLAUDE.md`, and both `Scripts/*-all.sh` files already reflect the new
ownership (steps 3 and 7 below are done). Steps 1, 2, 4, 5, and 6 --
the actual `docker compose down`/`up` cutover on the host -- are still
deferred until a maintenance window, since they require taking every
proxied stack down and back up: expect downtime for NPM, Pi-hole, Homepage,
Immich, Jellyfin, Authentik, and everything else on `proxy_net` for the
duration.

Do not run `docker compose up -d` on the host from this repo state until
that maintenance window: the compose files now declare
`infrastructure-networking` as the owner of `proxy_net`, which does not
match reality until the live cutover (steps 1-2, 4-6) is performed.

## Why

`proxy_net` is currently created by `dashboards-automation`
(`external: false`) and joined by every other stack except `dockge` as
`external: true`. That's backwards: `infrastructure-networking` is the
stack that holds Nginx Proxy Manager, the actual reverse proxy `proxy_net`
is named for. `dashboards-automation` (Homepage, Home Assistant, Uptime
Kuma, Grafana, Prometheus, node-exporter, Loki, Promtail) has nothing to
do with proxying -- it just happened to own the network because of
deployment order, not design.

This is a purely organizational fix. Docker doesn't care semantically
which compose file creates a bridge network, so there's no functional or
performance difference. The only real effect is startup-order: after this
swap, `infrastructure-networking` must be up before any other stack
starts, and `dashboards-automation` becomes a regular joiner like everyone
else.

## What Changes

### Compose files

Only the top-level `networks:` block in two files changes. Every service
block just lists `- proxy_net` and needs no edits.

| Stack | Before | After |
|---|---|---|
| `dashboards-automation` | `proxy_net: { name: proxy_net, external: false }` | `proxy_net: { external: true }` |
| `infrastructure-networking` | `proxy_net: { external: true }` | `proxy_net: { name: proxy_net, external: false }` |
| `auth`, `media-gaming`, `tools`, `llm` | `proxy_net: { external: true }` | unchanged |
| `dockge` | not on `proxy_net` | unchanged |

### Docs and scripts referencing the old ownership

- `CLAUDE.md` -- "Shared Network Dependency" section currently reads:
  > `proxy_net` is a Docker bridge network created by `dashboards-automation`
  > (`external: false`). All other stacks except `dockge` join it as
  > `external: true`. **`dashboards-automation` must be running before any
  > other stack starts.**

  Flip the stack names so `infrastructure-networking` is the creator and
  the one that must start first.
- `Scripts/startup-all.sh` -- `STACK_ORDER` currently starts with
  `dashboards-automation`; move `infrastructure-networking` to the front
  instead.
- `Scripts/shutdown-all.sh` -- `STACK_ORDER` currently ends with
  `dashboards-automation`; move `infrastructure-networking` to the end
  instead.
- Guides mentioning `proxy_net` -- confirm whether each needs a wording
  change (some may just reference joining it, not ownership):
  - `Guides/networking/nginx-proxy-manager-guide.md`
  - `Guides/networking/pihole-guide.md`
  - `Guides/getting-started/homelab-guide.md`
  - `Guides/stacks/dashboards-automation-guide.md`
  - `Guides/stacks/media-gaming-guide.md`
  - `Guides/stacks/tools-guide.md`
  - `Guides/stacks/llm-stack-guide.md`

## Why This Requires Downtime

Docker will not let a network's owner change while containers are
attached to it. The network has to be fully torn down -- not just
stopped -- and recreated by the new owner before anyone can reattach.
There's no rolling or zero-downtime way to do this on a single-host
Compose setup.

## Procedure

Run from `/opt/docker/stacks` on the host, during a maintenance window.

1. **Stop everything with `down`, not `stop`.**
   `docker compose down` in every stack directory (or adapt
   `Scripts/shutdown-all.sh` to use `down` for this one run --
   its normal `stop` leaves the network attached to stopped containers,
   which isn't enough here; the network needs to actually disappear).
2. **Confirm the network is gone:**
   ```bash
   docker network ls | grep proxy_net
   ```
   Expect no output. If it's still listed, find what's still attached
   with `docker network inspect proxy_net` and stop that container too.
3. **Edit the two compose files** per the table above:
   - `Docker/stacks/infrastructure-networking/compose.yaml`: add
     `name: proxy_net` and change `external: true` -> `external: false`.
   - `Docker/stacks/dashboards-automation/compose.yaml`: remove
     `name: proxy_net`, change `external: false` -> `external: true`.
4. **Bring up `infrastructure-networking` first:**
   ```bash
   cd Docker/stacks/infrastructure-networking && docker compose up -d
   ```
   Confirm the network now exists: `docker network ls | grep proxy_net`.
5. **Bring up every other stack** -- `dashboards-automation`, `auth`,
   `media-gaming`, `tools`, `llm`, `dockge` -- in any order; they all
   attach as `external: true` and the network already exists.
6. **Verify:**
   - `docker compose ps` clean (all `running`) in every stack directory.
   - Hit a couple of proxied hostnames through NPM
     (`*.home.bremmer.zone`) to confirm the proxy still resolves and
     routes correctly.
7. **Update the docs and scripts** listed above, and commit everything
   -- compose changes plus doc/script changes -- together.
8. **Remove this migration folder**
   (`Migrations/proxy-net-ownership-swap/`) once step 6 is
   confirmed clean.

## Rollback

If step 4 or 5 fails (network doesn't come up, a stack can't attach),
reverse the two compose edits and repeat steps 1-2-4-5 with the original
owner. Nothing here touches volumes or persistent data, so rollback
carries the same downtime cost but no data risk.

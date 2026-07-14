# V2.3 — Minor Update to Production

Production is currently running the deployed state under `Docker/` (tagged
`v2.2.0`). `Migrations/V2.3/` holds a minor, low-risk update to that running
state: a single new Docker Compose service with no hardware dependency and
no new secrets. It's tracked as its own versioned batch rather than a
standalone `Migrations/` item because it's meant to ship as a discrete
update to production, the same way `V3/` is a batch aimed at its own future
promotion.

Nothing under `V2.3/` is running yet. Each subfolder is one staged item,
self-contained with its own `README.md`.

## Promotion

Once a `V2.3/` item is verified working:

1. Merge its config into the relevant `Docker/stacks/` service or host
   config, following the existing file layout there.
2. Add or update the relevant guide in the
   [`Homelab-wiki`](https://github.com/praclarush/Homelab-wiki) repo.
3. Remove the item's folder from `Migrations/V2.3/`.

## Staged Items

| Item | Depends on | Summary |
|------|-----------|---------|
| [dispatcharr-iptv](dispatcharr-iptv/README.md) | Nothing (config-only; an IPTV provider subscription is only needed to watch anything beyond the free test source) | Dispatcharr IPTV connection manager, added to `media-gaming`, sitting between IPTV source(s) and Jellyfin Live TV |
| [proxy-net-network-ownership](proxy-net-network-ownership/README.md) | A planned maintenance window (requires a brief full-homelab outage) | `proxy_net` is Docker-labeled as owned by `dashboards-automation` instead of `infrastructure-networking` -- cosmetic today, documents the fix procedure for later |

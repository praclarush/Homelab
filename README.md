# HomeLab Stack: Infrastructure, Automation & Media

A modular Docker Compose-based home lab running on a dedicated Linux
mini PC, backed by Synology NAS storage and managed through a Ubiquiti
network environment.

**For full documentation** -- setup guides, per-stack how-tos, networking,
and operations -- see the [`Homelab-wiki`](https://github.com/praclarush/Homelab-wiki)
repo, starting at its [README.md](https://github.com/praclarush/Homelab-wiki/blob/master/README.md).
This repo stays a quick-reference companion: service inventory, ports,
`.env` contents, and directory layout.

## Overview

The environment is organized into three hardware tiers:

-   **Network Layer (Ubiquiti)**
    -   VLAN management and traffic routing
    -   DHCP services configured to use Pi-hole for network-wide DNS
        filtering
-   **Compute Layer (Linux Mini PC)**
    -   Primary Docker host running Ubuntu/Debian
    -   Local NVMe storage for container configurations and databases
    -   Intel Quick Sync (`/dev/dri`) enabled for hardware-accelerated
        media processing
-   **Storage Layer (Synology NAS)**
    -   Centralized storage backend
    -   Media libraries and large application assets mounted via NFS
    -   Keeps application runtime separate from bulk storage

------------------------------------------------------------------------

## Current Version

**v2.2.0** -- the version of the state deployed in [`Docker/stacks/`](Docker/stacks/).
Bump this when a versioned [`Migrations/`](Migrations/) batch (e.g.
[`Migrations/V3/`](Migrations/V3/)) is promoted into `Docker/stacks/`, per
the versioning convention in [Repository Layout](#repository-layout).

------------------------------------------------------------------------

## Physical Devices & Hostnames

Non-IoT hardware on the network follows a themed naming convention.
Smart home / IoT devices are not hostname-assigned individually -- they're
managed through Home Assistant instead.

| Device Type | Hostname | Network Role / Purpose | Lore Context |
| :---- | :---- | :---- | :---- |
| **Gateway Router** | blackwall | WAN Edge, Traffic Management | The lethal AI barrier separating the safe Net from chaotic rogue code. |
| **Network Switch** | blackwall-node | Local LAN Hardware Distribution | Direct extensions of the primary barrier infrastructure. |
| **Mini Switch** | Blackwall-Splinter | Local LAN Hardware Distribution (4-port) | A splinter of the primary barrier infrastructure. |
| **Access Point** | netwatch | Wireless Stream Oversight (Wi-Fi) | The corporate security force constantly monitoring local signals. |
| **Main Server** | mikoshi | Orchestration & Automation Hub | The ultimate data fortress holding the digital constructs of your smart home. |
| **Network Storage** | ghost-buffer | Mass Storage & Encrypted Backups | A dark-net repository caching digital constructs and hidden data. |
| **DNS Sinkhole** | black-ice | Ad & Tracker Countermeasure | Lethal defense programs deployed to fry malicious data streams. |
| **Main Rig** | afterlife | Primary Interfacing Machine (Desktop) | The legendary club where the heaviest data deals and operations go down. |
| **Mobile Comms** | cyberdeck | Remote Access & Node Controls | Your pocket-sized, custom-tuned rig used to slice into nodes on the fly. |

`mikoshi` is this repository's Docker host (the mini PC referenced
throughout as the Compute Layer). `ghost-buffer` is the Synology NAS
(Storage Layer). See
[`hardware-configuration/`](https://github.com/praclarush/Homelab-wiki/tree/master/hardware-configuration/)
in the `Homelab-wiki` repo for host-level hardware setup guides that fall
outside Docker Compose (e.g. UPS monitoring).

------------------------------------------------------------------------

## Repository Layout

The repository root holds three top-level folders:

- **[`Docker/`](Docker/)** -- the current, deployed state.
  [`Docker/stacks/`](Docker/stacks/) has one folder per stack, each with a
  single `compose.yaml`; there is no version history to reconcile within it.
  [`Docker/config/`](Docker/config/) holds reference copies of host-level
  Linux configs (`/etc/fstab`, Netplan, CrowdSec bouncer, Docker daemon).
- **[`Migrations/`](Migrations/)** -- staged changes not yet deployed,
  typically blocked on hardware or another external dependency. Most live
  under [`Migrations/V3/`](Migrations/V3/) (a versioned batch -- see
  [`Migrations/V3/README.md`](Migrations/V3/README.md) for its promotion
  process); a versioned `V2.x/` batch -- a minor update to the
  currently-deployed state rather than a future major version -- gets
  created the same way once there's another low-risk update to stage;
  newer, unbatched items are added as standalone folders directly under
  `Migrations/`. Each item is self-contained with its own `README.md`.
- **[`Scripts/`](Scripts/)** -- host-side operational scripts not tied to a
  single stack: `startup-all.sh`/`shutdown-all.sh` bring every stack up or
  down in dependency order, and `add-npm-proxy-hosts.ps1` bulk-creates NPM
  proxy hosts via its API instead of the manual steps in
  [nginx-proxy-manager-guide.md](https://github.com/praclarush/Homelab-wiki/blob/master/networking/nginx-proxy-manager-guide.md).

## Documentation

How-to guides (deployment, networking, per-stack setup, operations) live in
the separate [`praclarush/Homelab-wiki`](https://github.com/praclarush/Homelab-wiki)
repo, git-synced into the WikiJS instance this homelab runs
(`https://wiki.home.example.com`).

**Start at [its README.md](https://github.com/praclarush/Homelab-wiki/blob/master/README.md).**
This file stays a quick-reference companion: service inventory, ports,
`.env` contents, and directory layout -- not a how-to guide.

------------------------------------------------------------------------

## Stacks

| Stack | Services |
|-------|----------|
| `dashboards-automation` | Homepage, Home Assistant, Uptime Kuma, Grafana, Prometheus, Loki, Promtail, nut-exporter |
| `dockge` | Dockge |
| `infrastructure-networking` | Pi-hole, Nginx Proxy Manager, Watchtower, ntfy, Tailscale, CrowdSec |
| `media-gaming` | AMP, Immich, Immich Machine Learning, Jellyfin, Audiobookshelf, Kavita |
| `auth` | Authentik, PostgreSQL, Redis |
| `tools` | WikiJS, PostgreSQL, pgAdmin, Stirling PDF, Mealie, n8n, IT Tools, Actual Budget, Paperless-ngx, Grocy, Linkwarden, Backrest |
| `llm` | Ollama, Open WebUI |

Each stack in [`Docker/stacks/`](Docker/stacks/) has a single `compose.yaml`
representing its full current state.

------------------------------------------------------------------------

## Service Quick Reference

All hosted services, their stack, direct access port, and proxy URL.
Services are available at both the direct IP:port and via NPM at `*.home.example.com`.
Internal-only services (no exposed port) are marked with a dash.

| Service | Stack | Port | Proxy URL | Purpose |
|---------|-------|------|-----------|---------|
| Homepage | `dashboards-automation` | 3000 | `homepage.home.example.com` | Service dashboard |
| Home Assistant | `dashboards-automation` | 8123 | `homeassistant.home.example.com` | Home automation |
| Uptime Kuma | `dashboards-automation` | 3001 | `uptime.home.example.com` | Uptime monitoring |
| Grafana | `dashboards-automation` | 3002 | `grafana.home.example.com` | Metrics dashboards |
| Prometheus | `dashboards-automation` | 9090 | `prometheus.home.example.com` | Metrics collection |
| node-exporter | `dashboards-automation` | 9100 | — | Host system metrics (host network) |
| Dockge | `dockge` | 5001 | `dockge.home.example.com` | Docker stack manager |
| Nginx Proxy Manager | `infrastructure-networking` | 80 / 443 / 81 (admin) | — | Reverse proxy and SSL (admin direct only) |
| Pi-hole | `infrastructure-networking` | 53 (DNS), 8080 (web) | `pihole.home.example.com` | Network-wide DNS filtering |
| Watchtower | `infrastructure-networking` | — | — | Automated container updates |
| ntfy | `infrastructure-networking` | 8082 | `ntfy.home.example.com` | Push notifications |
| Tailscale | `infrastructure-networking` | — | — | Remote access (host network) |
| AMP | `media-gaming` | 8081 | `amp.home.example.com` | Game server management |
| Immich | `media-gaming` | 2283 | `photos.home.example.com` | Photo and video library |
| Immich Machine Learning | `media-gaming` | — | — | Smart search and face recognition (internal) |
| Immich PostgreSQL | `media-gaming` | — | — | Immich database (internal) |
| Immich Redis | `media-gaming` | — | — | Immich job queue (internal) |
| Jellyfin | `media-gaming` | 8096 | `jellyfin.home.example.com` | Media server |
| Authentik | `auth` | 9000 / 9443 | `auth.home.example.com` | Single sign-on and identity provider |
| Authentik PostgreSQL | `auth` | — | — | Authentik database (internal) |
| Authentik Redis | `auth` | — | — | Authentik cache (internal) |
| WikiJS | `tools` | 3003 | `wiki.home.example.com` | Internal wiki and documentation |
| WikiJS PostgreSQL | `tools` | — | — | WikiJS database (internal) |
| pgAdmin | `tools` | 5050 | `pgadmin.home.example.com` | PostgreSQL web admin |
| Stirling PDF | `tools` | 8083 | `pdf.home.example.com` | PDF tools |
| Mealie | `tools` | 9925 | `mealie.home.example.com` | Recipe manager |
| n8n | `tools` | 5678 | `n8n.home.example.com` | Workflow automation |
| IT Tools | `tools` | 8084 | `it-tools.home.example.com` | Developer utilities |
| Actual Budget | `tools` | 5006 | `budget.home.example.com` | Personal finance |
| Paperless-ngx | `tools` | 8085 | `paperless.home.example.com` | Document management |
| Paperless PostgreSQL | `tools` | — | — | Paperless database (internal) |
| Paperless Redis | `tools` | — | — | Paperless queue (internal) |
| Grocy | `tools` | 9283 | `grocy.home.example.com` | Household groceries, inventory, and chores |
| Linkwarden | `tools` | 3005 | `links.home.example.com` | Bookmark manager with page archiving |
| Linkwarden PostgreSQL | `tools` | — | — | Linkwarden database (internal) |
| Backrest | `tools` | 9898 | `backrest.home.example.com` | Restic backup UI, backs up to NAS |
| Audiobookshelf | `media-gaming` | 13378 | `abs.home.example.com` | Audiobooks and podcasts |
| Kavita | `media-gaming` | 5000 | `kavita.home.example.com` | Ebook and comic reader |
| Loki | `dashboards-automation` | 3100 | — | Log aggregation, queried from Grafana (internal) |
| Promtail | `dashboards-automation` | — | — | Log collector, ships to Loki (internal) |
| nut-exporter | `dashboards-automation` | 9995 | — | Prometheus exporter for the host's NUT UPS server (internal) |
| CrowdSec | `infrastructure-networking` | — | — | Intrusion detection, reads NPM logs (internal) |
| Ollama | `llm` | 11434 | — | LLM inference API |
| Open WebUI | `llm` | 3004 | `llm.home.example.com` | Chat interface |

------------------------------------------------------------------------

## Directory Structure

All stacks are stored under `/opt/docker/stacks/` on the host. Following
[`operations/git-deployment-guide.md`](https://github.com/praclarush/Homelab-wiki/blob/master/operations/git-deployment-guide.md)
in the `Homelab-wiki` repo, this path is a symlink into a clone of this
repository at `/srv/git/homelab`, pointed at the `Docker/stacks/` tree, so
config changes made on the host can be committed and pushed directly,
and changes pushed elsewhere can be pulled and applied with
`docker compose up -d`.

``` text
/opt/docker/stacks/
├── dashboards-automation/
│   ├── compose.yaml             # Homepage, Home Assistant, Uptime Kuma, Grafana, Prometheus, node-exporter, Loki, Promtail, nut-exporter
│   ├── .env                     # Grafana password, MESHNET_IP (Home Assistant remote access)
│   ├── prometheus/config/       # prometheus.yml (copy from repo)
│   ├── loki/                    # Loki config and data
│   ├── promtail/                # Promtail config
│   └── homepage/config/
│
├── dockge/
│   └── compose.yaml
│
├── infrastructure-networking/
│   ├── compose.yaml             # NPM, Pi-hole, Watchtower, ntfy, Tailscale, CrowdSec
│   ├── .env                     # Pi-hole password, Tailscale auth key, ntfy topic/token, MESHNET_IP (ntfy remote access)
│   ├── pihole/config/
│   ├── pihole/dnsmasq/
│   ├── npm/
│   ├── ntfy/cache/
│   ├── ntfy/config/
│   ├── ntfy/lib/                # ntfy auth database (users, tokens, ACLs)
│   ├── tailscale/state/
│   └── crowdsec/
│
├── media-gaming/
│   ├── compose.yaml             # AMP, Immich, Immich Machine Learning, Jellyfin, Audiobookshelf, Kavita
│   ├── .env                     # Immich database credentials, MESHNET_IP (Immich/Jellyfin/Audiobookshelf/Kavita remote access)
│   ├── amp/datastore/
│   ├── immich/postgres/         # Keep on NVMe
│   ├── immich/redis/
│   ├── immich/cache/
│   ├── immich/model-cache/
│   ├── jellyfin/
│   ├── audiobookshelf/          # Audiobookshelf config and metadata
│   └── kavita/config/
│
├── auth/
│   ├── compose.yaml
│   ├── .env                     # Authentik credentials and secret key
│   ├── postgres/
│   ├── redis/
│   ├── media/
│   └── certs/
│
├── tools/
│   ├── compose.yaml             # WikiJS, pgAdmin, Stirling PDF, Mealie, n8n, IT Tools, Actual Budget, Paperless-ngx, Grocy, Linkwarden, Backrest
│   ├── .env                     # Stack credentials (gitignored), MESHNET_IP (WikiJS/Mealie/Paperless-ngx/Grocy remote access)
│   ├── postgres/                # WikiJS database data
│   ├── pgadmin/                 # pgAdmin data
│   ├── stirling-pdf/            # Stirling PDF config and OCR data
│   ├── mealie/                  # Mealie recipe data
│   ├── n8n/                     # n8n workflow data
│   ├── actual-budget/           # Actual Budget data
│   ├── paperless/               # Paperless-ngx data, media, postgres, redis
│   ├── grocy/config/            # Grocy config and database
│   ├── linkwarden/              # Linkwarden data and postgres
│   └── backrest/                # Backrest config and metadata
│
└── llm/
    ├── compose.yaml             # Ollama and Open WebUI
    ├── .env                     # VLAN11_IP (gitignored)
    ├── models/                  # Ollama model files (large, gitignored)
    └── open-webui/              # Open WebUI data
```

------------------------------------------------------------------------

## Deployment Order

`infrastructure-networking` first (creates the `proxy_net` network every
other stack but `dockge` joins), then `dockge`, `dashboards-automation`,
`media-gaming`, `auth`, `tools`, `llm` -- in any order after that. Full
prerequisites (disabling `systemd-resolved`, mounting the six NAS shares,
Intel Quick Sync, VLAN trunking) and step-by-step deployment for each
stack are in [`getting-started/homelab-guide.md`](https://github.com/praclarush/Homelab-wiki/blob/master/getting-started/homelab-guide.md)
in the `Homelab-wiki` repo.

------------------------------------------------------------------------

## Stack Reference

Ports are in [Service Quick Reference](#service-quick-reference) above.
`.env` contents per stack are set up step-by-step in
[`getting-started/homelab-guide.md`](https://github.com/praclarush/Homelab-wiki/blob/master/getting-started/homelab-guide.md)
section 5 of the `Homelab-wiki` repo. Deployment, first-time setup, and
stack-specific notes (Watchtower's auto-update policy, Postgres backup
rotation, memory limits, forward-auth wiring, etc.) live in that same
guide and the per-stack guides under
[`stacks/`](https://github.com/praclarush/Homelab-wiki/tree/master/stacks/):
[dashboards-automation](https://github.com/praclarush/Homelab-wiki/blob/master/stacks/dashboards-automation-guide.md),
[infrastructure-networking](https://github.com/praclarush/Homelab-wiki/blob/master/stacks/infrastructure-networking-guide.md),
[media-gaming](https://github.com/praclarush/Homelab-wiki/blob/master/stacks/media-gaming-guide.md),
[tools](https://github.com/praclarush/Homelab-wiki/blob/master/stacks/tools-guide.md),
[llm](https://github.com/praclarush/Homelab-wiki/blob/master/stacks/llm-stack-guide.md).
`auth` and `dockge` have no guide beyond the getting-started guide --
neither has services added on top of the base deployment.

------------------------------------------------------------------------

## Maintenance

### Updating Stacks

``` bash
docker compose pull
docker compose up -d
```

### Applying a compose.yaml Change

`docker restart <service>` reuses the existing container's config as-is --
it does **not** re-read `compose.yaml`. If you edited the file (new
environment variable, `tty`/`stdin_open`, port, volume, etc.), the
container must be recreated, not just restarted:

``` bash
docker compose up -d <service>
```

If it doesn't pick up the change, force it:

``` bash
docker compose up -d --force-recreate <service>
```

Confirm the running container actually has the new config (don't just
trust that it looks "up"):

``` bash
docker inspect <service> --format '{{json .Config}}'
```

### Viewing Logs

``` bash
docker compose logs -f <service_name>
```

### Backup

Back up: compose files, configuration directories, `.env` files
(store separately from version control).

Exclude: database volumes (`./immich/postgres`, `./auth/postgres`),
application caches.

Use Synology Hyper Backup for media protection. See
[`stacks/media-gaming-guide.md`](https://github.com/praclarush/Homelab-wiki/blob/master/stacks/media-gaming-guide.md)
in the `Homelab-wiki` repo for the Immich database backup command and the
per-stack guides for other stack-specific backup procedures.

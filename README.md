# HomeLab Stack: Infrastructure, Automation & Media

A modular Docker Compose-based home lab running on a dedicated Linux
mini PC, backed by Synology NAS storage and managed through a Ubiquiti
network environment.

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

## Repository Layout

This repository holds two parallel snapshots of the homelab:

- **[`V2/`](V2/)** -- the current state, and what the rest of this file
  describes. Each stack has a single `compose.yaml`; there is no version
  history to reconcile within it.
- **[`V1/`](V1/)** -- the prior, versioned snapshot, preserved for history.
  Several stacks there carry multiple `compose.vN.yaml` files representing
  incremental migrations. Not maintained going forward.

## Documentation

The [`V2/guides/`](V2/guides/) directory is organized like a wiki -- it will
eventually be moved into the WikiJS instance this homelab runs. Start at
[`V2/guides/README.md`](V2/guides/README.md) for the full index. Quick reference:

| File | Purpose |
|------|---------|
| [`V2/guides/getting-started/homelab-guide.md`](V2/guides/getting-started/homelab-guide.md) | Full setup guide: Linux basics, prerequisites, NordVPN Meshnet remote access, and initial deployment of all six core stacks |
| [`V2/guides/networking/nginx-proxy-manager-guide.md`](V2/guides/networking/nginx-proxy-manager-guide.md) | NPM reverse proxy setup, Cloudflare/Let's Encrypt TLS, all proxy host configurations |
| [`V2/guides/networking/pihole-guide.md`](V2/guides/networking/pihole-guide.md) | Pi-hole deployment, network-wide DNS handoff, local/wildcard DNS records, blocklist and Teleporter maintenance |
| [`V2/guides/operations/git-deployment-guide.md`](V2/guides/operations/git-deployment-guide.md) | Cloning this repo onto the Ubuntu Server host as a live git working tree, gitignore correctness, and the push/pull workflow for config changes |
| [`V2/guides/stacks/tools-guide.md`](V2/guides/stacks/tools-guide.md) | `tools` stack beyond WikiJS: pgAdmin, Stirling PDF, Mealie, n8n, IT Tools, Actual Budget, Paperless-ngx, Grocy, Linkwarden, Backrest |
| [`V2/guides/stacks/media-gaming-guide.md`](V2/guides/stacks/media-gaming-guide.md) | `media-gaming` stack beyond AMP and Immich: Jellyfin, Audiobookshelf, Kavita |
| [`V2/guides/stacks/dashboards-automation-guide.md`](V2/guides/stacks/dashboards-automation-guide.md) | `dashboards-automation` stack beyond Homepage, Home Assistant, Uptime Kuma, Grafana, Prometheus: Loki, Promtail |
| [`V2/guides/stacks/infrastructure-networking-guide.md`](V2/guides/stacks/infrastructure-networking-guide.md) | `infrastructure-networking` stack beyond NPM, Pi-hole, Watchtower, ntfy, Tailscale: CrowdSec |
| [`V2/guides/stacks/llm-stack-guide.md`](V2/guides/stacks/llm-stack-guide.md) | Local LLM stack setup (Ollama + Open WebUI), model management, air-gapped operation |
| [`V2/stacks/compose-review-notes.md`](V2/stacks/compose-review-notes.md) | Rationale for compose file changes, deferred Postgres migration procedure |
| [`V2/config/README.md`](V2/config/README.md) | Complete reference copies of host-level Linux configs (`/etc/fstab`, Netplan, CrowdSec bouncer) referenced by the guides above |

------------------------------------------------------------------------

## Stacks

| Stack | Services |
|-------|----------|
| `dashboards-automation` | Homepage, Home Assistant, Uptime Kuma, Grafana, Prometheus, Loki, Promtail |
| `dockge` | Dockge |
| `infrastructure-networking` | Pi-hole, Nginx Proxy Manager, Watchtower, ntfy, Tailscale, CrowdSec |
| `media-gaming` | AMP, Immich, Immich Machine Learning, Jellyfin, Audiobookshelf, Kavita |
| `auth` | Authentik, PostgreSQL, Redis |
| `tools` | WikiJS, PostgreSQL, pgAdmin, Stirling PDF, Mealie, n8n, IT Tools, Actual Budget, Paperless-ngx, Grocy, Linkwarden, Backrest |
| `llm` | Ollama, Open WebUI |

Each stack in [`V2/stacks/`](V2/stacks/) has a single `compose.yaml`
representing its full current state. [`V1/stacks/`](V1/stacks/) preserves
the prior versioned snapshot (`compose.yaml` plus `compose.vN.yaml` per
stack, where applicable) for history.

------------------------------------------------------------------------

## Service Quick Reference

All hosted services, their stack, direct access port, and proxy URL.
Services are available at both the direct IP:port and via NPM at `*.home.bremmer.zone`.
Internal-only services (no exposed port) are marked with a dash.

| Service | Stack | Port | Proxy URL | Purpose |
|---------|-------|------|-----------|---------|
| Homepage | `dashboards-automation` | 3000 | `homepage.home.bremmer.zone` | Service dashboard |
| Home Assistant | `dashboards-automation` | 8123 | `homeassistant.home.bremmer.zone` | Home automation |
| Uptime Kuma | `dashboards-automation` | 3001 | `uptime.home.bremmer.zone` | Uptime monitoring |
| Grafana | `dashboards-automation` | 3002 | `grafana.home.bremmer.zone` | Metrics dashboards |
| Prometheus | `dashboards-automation` | 9090 | `prometheus.home.bremmer.zone` | Metrics collection |
| node-exporter | `dashboards-automation` | 9100 | — | Host system metrics (host network) |
| Dockge | `dockge` | 5001 | `dockge.home.bremmer.zone` | Docker stack manager |
| Nginx Proxy Manager | `infrastructure-networking` | 80 / 443 / 81 (admin) | — | Reverse proxy and SSL (admin direct only) |
| Pi-hole | `infrastructure-networking` | 53 (DNS), 8080 (web) | `pihole.home.bremmer.zone` | Network-wide DNS filtering |
| Watchtower | `infrastructure-networking` | — | — | Automated container updates |
| ntfy | `infrastructure-networking` | 8082 | `ntfy.home.bremmer.zone` | Push notifications |
| Tailscale | `infrastructure-networking` | — | — | Remote access (host network) |
| AMP | `media-gaming` | 8081 | `amp.home.bremmer.zone` | Game server management |
| Immich | `media-gaming` | 2283 | `photos.home.bremmer.zone` | Photo and video library |
| Immich Machine Learning | `media-gaming` | — | — | Smart search and face recognition (internal) |
| Immich PostgreSQL | `media-gaming` | — | — | Immich database (internal) |
| Immich Redis | `media-gaming` | — | — | Immich job queue (internal) |
| Jellyfin | `media-gaming` | 8096 | `jellyfin.home.bremmer.zone` | Media server |
| Authentik | `auth` | 9000 / 9443 | `auth.home.bremmer.zone` | Single sign-on and identity provider |
| Authentik PostgreSQL | `auth` | — | — | Authentik database (internal) |
| Authentik Redis | `auth` | — | — | Authentik cache (internal) |
| WikiJS | `tools` | 3003 | `wiki.home.bremmer.zone` | Internal wiki and documentation |
| WikiJS PostgreSQL | `tools` | — | — | WikiJS database (internal) |
| pgAdmin | `tools` | 5050 | `pgadmin.home.bremmer.zone` | PostgreSQL web admin |
| Stirling PDF | `tools` | 8083 | `pdf.home.bremmer.zone` | PDF tools |
| Mealie | `tools` | 9925 | `mealie.home.bremmer.zone` | Recipe manager |
| n8n | `tools` | 5678 | `n8n.home.bremmer.zone` | Workflow automation |
| IT Tools | `tools` | 8084 | `it-tools.home.bremmer.zone` | Developer utilities |
| Actual Budget | `tools` | 5006 | `budget.home.bremmer.zone` | Personal finance |
| Paperless-ngx | `tools` | 8085 | `paperless.home.bremmer.zone` | Document management |
| Paperless PostgreSQL | `tools` | — | — | Paperless database (internal) |
| Paperless Redis | `tools` | — | — | Paperless queue (internal) |
| Grocy | `tools` | 9283 | `grocy.home.bremmer.zone` | Household groceries, inventory, and chores |
| Linkwarden | `tools` | 3005 | `links.home.bremmer.zone` | Bookmark manager with page archiving |
| Linkwarden PostgreSQL | `tools` | — | — | Linkwarden database (internal) |
| Backrest | `tools` | 9898 | `backrest.home.bremmer.zone` | Restic backup UI, backs up to NAS |
| Audiobookshelf | `media-gaming` | 13378 | `abs.home.bremmer.zone` | Audiobooks and podcasts |
| Kavita | `media-gaming` | 5000 | `kavita.home.bremmer.zone` | Ebook and comic reader |
| Loki | `dashboards-automation` | 3100 | — | Log aggregation, queried from Grafana (internal) |
| Promtail | `dashboards-automation` | — | — | Log collector, ships to Loki (internal) |
| CrowdSec | `infrastructure-networking` | — | — | Intrusion detection, reads NPM logs (internal) |
| Ollama | `llm` | 11434 | — | LLM inference API |
| Open WebUI | `llm` | 3004 | `llm.home.bremmer.zone` | Chat interface |

------------------------------------------------------------------------

## Directory Structure

All stacks are stored under `/opt/docker/stacks/` on the host. Following
[`V2/guides/operations/git-deployment-guide.md`](V2/guides/operations/git-deployment-guide.md),
this path is a symlink into a clone of this
repository at `/opt/docker/repo`, pointed at the `V2/stacks/` tree, so
config changes made on the host can be committed and pushed directly,
and changes pushed elsewhere can be pulled and applied with
`docker compose up -d`.

``` text
/opt/docker/stacks/
├── dashboards-automation/
│   ├── compose.yaml             # Homepage, Home Assistant, Uptime Kuma, Grafana, Prometheus, node-exporter, Loki, Promtail
│   ├── .env                     # Grafana password
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
│   ├── .env                     # Pi-hole password, Tailscale auth key, ntfy topic
│   ├── pihole/config/
│   ├── pihole/dnsmasq/
│   ├── npm/
│   ├── ntfy/
│   ├── tailscale/state/
│   └── crowdsec/
│
├── media-gaming/
│   ├── compose.yaml             # AMP, Immich, Immich Machine Learning, Jellyfin, Audiobookshelf, Kavita
│   ├── .env                     # Immich database credentials
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
│   ├── .env                     # Stack credentials (gitignored)
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

`dashboards-automation` must be deployed first. It creates the
`proxy_net` Docker bridge network that all other stacks join as
`external: true`. Bringing it down removes the network and breaks the
other stacks.

1. `dashboards-automation`
2. `dockge`
3. `infrastructure-networking`
4. `media-gaming`
5. `auth`
6. `tools`
7. `llm`

`dockge` is standalone and can be deployed in any order.

------------------------------------------------------------------------

## Prerequisites

### Disable systemd-resolved

Pi-hole binds to port 53. `systemd-resolved` holds that port by default
on Ubuntu/Debian and must be stopped before the
`infrastructure-networking` stack will start cleanly.

``` bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

### Mount Synology Storage

NFS shares must be permanently mounted via `/etc/fstab` before starting
`media-gaming`. Immich uploads go to `/mnt/synology/immich` and
Jellyfin media is served from `/mnt/synology/media`.

------------------------------------------------------------------------

## Stack Reference

### dashboards-automation

See [`V2/guides/stacks/dashboards-automation-guide.md`](V2/guides/stacks/dashboards-automation-guide.md) for Loki and Promtail setup beyond the base Homepage/Home Assistant/Uptime Kuma/Grafana/Prometheus deployment.

**Ports**

| Service | Port |
|---------|------|
| Homepage | 3000 |
| Home Assistant | 8123 |
| Uptime Kuma | 3001 |
| Grafana | 3002 |
| Prometheus | 9090 |
| node-exporter | 9100 (host network) |
| Loki | 3100 |

**Environment file** -- `./dashboards-automation/.env`

``` text
GRAFANA_PASSWORD=
VLAN11_IP=192.168.11.10
HOMEPAGE_VAR_IMMICH_KEY=
HOMEPAGE_VAR_JELLYFIN_KEY=
HOMEPAGE_VAR_PIHOLE_KEY=
```

**Notes**

-   Homepage's dashboard config is checked into the repo at
    `V2/stacks/dashboards-automation/homepage/config/`, not generated
    blank on first start. See
    [`V2/guides/getting-started/homelab-guide.md`](V2/guides/getting-started/homelab-guide.md)
    section 8.4 for the remaining placeholder values to fill in
    (location, the `HOMEPAGE_VAR_*` keys above, container names).
-   Prometheus requires `./prometheus/config/prometheus.yml` to exist
    before starting. Copy it from `V2/stacks/dashboards-automation/prometheus/prometheus.yml`
    in the repository.
-   node-exporter runs with `network_mode: host` for accurate system
    metrics. Prometheus reaches it via `host.docker.internal:9100`.
-   Grafana's Prometheus data source URL (configured post-deploy):
    `http://prometheus:9090`
-   Loki requires config files copied from the repo before deploying.
    After deploy, add Loki as a Grafana data source at
    `http://loki:3100`. See [`V2/guides/stacks/dashboards-automation-guide.md`](V2/guides/stacks/dashboards-automation-guide.md).

------------------------------------------------------------------------

### dockge

**Ports**

| Service | Port |
|---------|------|
| Dockge | 5001 |

**Environment file** -- `./dockge/.env`

``` text
VLAN11_IP=192.168.11.10
```

Manages stacks at `/opt/docker/stacks` on the host.

**Notes**

-   Dockge has no `networks:` configuration and is not on `proxy_net`.
    NPM proxies it via the host IP (`192.168.11.10:5001`) rather than
    by container name.

------------------------------------------------------------------------

### infrastructure-networking

See [`V2/guides/stacks/infrastructure-networking-guide.md`](V2/guides/stacks/infrastructure-networking-guide.md) for CrowdSec setup beyond the base NPM/Pi-hole/Watchtower/ntfy/Tailscale deployment.

**Ports**

| Service | Port |
|---------|------|
| Nginx Proxy Manager (HTTP) | 80 |
| Nginx Proxy Manager (HTTPS) | 443 |
| Nginx Proxy Manager (admin) | 81 |
| Pi-hole (DNS) | 53 TCP/UDP |
| Pi-hole (web) | 8080 |
| ntfy | 8082 |
| Tailscale | host network |

**Environment file** -- `./infrastructure-networking/.env`

``` text
PIHOLE_PASSWORD=
TAILSCALE_AUTHKEY=
WATCHTOWER_NTFY_TOPIC=
VLAN11_IP=192.168.11.10
```

**Notes**

-   NPM is proxied via direct IP only (`192.168.11.10:81`). The admin
    panel is intentionally not routed through NPM itself.
-   Pi-hole wildcard DNS entry for `home.bremmer.zone` lives at
    `./pihole/dnsmasq/02-local-dns.conf`. See [`V2/guides/networking/nginx-proxy-manager-guide.md`](V2/guides/networking/nginx-proxy-manager-guide.md).
-   Remote access is provided by Tailscale. No port forwarding is
    required. See [`V2/guides/getting-started/homelab-guide.md`](V2/guides/getting-started/homelab-guide.md) for auth key generation.
-   Watchtower uses ntfy for update notifications. Set
    `WATCHTOWER_NTFY_TOPIC` to the topic name you subscribe to in the
    ntfy app (e.g. `watchtower`).
-   Watchtower only updates containers with the label
    `com.centurylinklabs.watchtower.enable=true`.
-   CrowdSec reads NPM logs from `./npm/logs` and detects attack
    patterns. Requires the firewall bouncer installed on the host to
    act on decisions. See [`V2/guides/stacks/infrastructure-networking-guide.md`](V2/guides/stacks/infrastructure-networking-guide.md).

------------------------------------------------------------------------

### media-gaming

See [`V2/guides/stacks/media-gaming-guide.md`](V2/guides/stacks/media-gaming-guide.md) for Jellyfin, Audiobookshelf, and Kavita setup beyond the base AMP/Immich deployment.

**Ports**

| Service | Port |
|---------|------|
| AMP | 8081 |
| Minecraft (example) | 25565 |
| Immich | 2283 |
| Jellyfin | 8096 |
| Audiobookshelf | 13378 |
| Kavita | 5000 |

**Environment file** -- `./media-gaming/.env`

``` text
DB_USERNAME=
DB_PASSWORD=
DB_DATABASE_NAME=
VLAN61_IP=192.168.61.10
```

**Notes**

-   Immich and Jellyfin both use Intel Quick Sync via `/dev/dri`.
-   Immich database (`./immich/postgres`) must stay on local NVMe
    storage. Media uploads (`/mnt/synology/immich`) mount from NAS.
-   Jellyfin media library path defaults to `/mnt/synology/media`.
    Adjust the volume mount in `compose.yaml` if your NAS path differs.
-   Audiobookshelf and Kavita mount from NAS at
    `/mnt/synology/audiobooks`, `/mnt/synology/podcasts`, and
    `/mnt/synology/books`. Each path must be the NAS share mounted over
    NFS on the host, not just a folder created on the NAS -- see
    [`V2/guides/stacks/media-gaming-guide.md`](V2/guides/stacks/media-gaming-guide.md)
    section 2 before deploying.
-   `immich-server` waits for Postgres and Redis health checks before
    starting. On a cold start expect 15-30 seconds before the UI is
    available.
-   The `immich-machine-learning` sidecar downloads models on first
    start (requires outbound internet). Models are cached at
    `./immich/model-cache` and do not re-download on subsequent starts.

### Immich Database Migration (deferred)

The current Postgres image (`tensorchord/pgvecto-rs:pg14-v0.2.0`) needs
to be migrated to `ghcr.io/immich-app/postgres:14-vectorchord0.3.0-pgvectors0.2.0`
at a planned maintenance window. This requires a dump and restore -- do
not change the image tag in-place. See `V2/stacks/compose-review-notes.md`
for the procedure.

------------------------------------------------------------------------

### tools

Single `compose.yaml` covering WikiJS plus every service added on top
of it. See [`V2/guides/stacks/tools-guide.md`](V2/guides/stacks/tools-guide.md)
for pgAdmin, Stirling PDF, Mealie, n8n, IT Tools, Actual Budget,
Paperless-ngx, Grocy, Linkwarden, and Backrest setup beyond the base
WikiJS deployment.

**Ports**

| Service | Port |
|---------|------|
| WikiJS | 3003 |
| pgAdmin | 5050 |
| Stirling PDF | 8083 |
| Mealie | 9925 |
| n8n | 5678 |
| IT Tools | 8084 |
| Actual Budget | 5006 |
| Paperless-ngx | 8085 |
| Grocy | 9283 |
| Linkwarden | 3005 |
| Backrest | 9898 |

**Environment file** -- `./tools/.env`

``` text
DB_USER=wikijs
DB_PASS=
DB_NAME=wikijs
VLAN11_IP=192.168.11.10
PGADMIN_EMAIL=
PGADMIN_PASSWORD=
N8N_ENCRYPTION_KEY=
PAPERLESS_DB_USER=
PAPERLESS_DB_PASS=
PAPERLESS_SECRET_KEY=
LINKWARDEN_DB_USER=
LINKWARDEN_DB_PASS=
LINKWARDEN_SECRET=
```

Grocy needs no entries here -- its `PUID`/`PGID`/`TZ` are set directly
in `compose.yaml`.

Generate `N8N_ENCRYPTION_KEY`, `PAPERLESS_SECRET_KEY`, and
`LINKWARDEN_SECRET` with:

``` bash
openssl rand -hex 32
```

**Notes**

-   WikiJS supports OIDC authentication via Authentik. Configure this
    post-deploy in the WikiJS admin panel to enable single sign-on.
-   WikiJS PostgreSQL is isolated from all other PostgreSQL containers
    in the stack. Paperless-ngx and Linkwarden each have their own
    dedicated PostgreSQL (and, for Paperless, Redis) containers.
-   Paperless-ngx: drop files into `./paperless/consume` to ingest
    documents automatically.
-   n8n webhook URL is configured for `https://n8n.home.bremmer.zone`.
    The NPM proxy host must exist before webhooks will work.
-   Grocy default login is `admin`/`admin` -- change the password
    immediately after first login.
-   Backrest mounts `/opt/docker/stacks` read-only and
    `/mnt/synology/backups` as the backup destination. The latter must
    be the NAS share mounted over NFS on the host, not just a folder
    created on the NAS -- see
    [`V2/guides/stacks/tools-guide.md`](V2/guides/stacks/tools-guide.md)
    section 2 before deploying.

------------------------------------------------------------------------

### auth

**Ports**

| Service | Port |
|---------|------|
| Authentik (HTTP) | 9000 |
| Authentik (HTTPS) | 9443 |

**Environment file** -- `./auth/.env`

``` text
PG_USER=
PG_PASS=
PG_DB=
AUTHENTIK_SECRET_KEY=
VLAN11_IP=192.168.11.10
```

Generate `AUTHENTIK_SECRET_KEY` with:

``` bash
openssl rand -hex 32
```

**Notes**

-   Initial admin account is created via the browser on first start at
    `http://192.168.11.10:9000/if/flow/initial-setup/`
-   Authentik integrates with Nginx Proxy Manager via forward auth to
    gate access to proxied services.

------------------------------------------------------------------------

### llm

**Ports**

| Service | Port |
|---------|------|
| Ollama API | 11434 |
| Open WebUI | 3004 |

**Environment file** -- `./llm/.env`

``` text
VLAN11_IP=192.168.11.10
```

**Notes**

-   Inference runs on CPU -- Intel UHD integrated graphics is not
    supported by Ollama's GPU acceleration. Expect 3-6 tokens/second
    for a 14B model.
-   Models are stored in `./models` and persist across container
    restarts and image updates.
-   Pull models while internet-connected before air-gapped operation.
    See [`V2/guides/stacks/llm-stack-guide.md`](V2/guides/stacks/llm-stack-guide.md) for model recommendations and pull
    commands.
-   Recommended model for this hardware: `qwen2.5-coder:14b` (~9 GB,
    strong at both code and general chat).

------------------------------------------------------------------------

## Maintenance

### Updating Stacks

``` bash
docker compose pull
docker compose up -d
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

Use Synology Hyper Backup for media protection.

### Immich Database Backup

``` bash
docker exec immich_postgres pg_dumpall -U <DB_USERNAME> > immich_backup.sql
```

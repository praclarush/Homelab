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

## Documentation

| File | Purpose |
|------|---------|
| `homelab-v1-configuration-guide.md` | Step-by-step setup guide for v1 stacks (Linux basics, prerequisites, initial deployment) |
| `homelab-v2-configuration-guide.md` | Migration guide from v1 to v2 (VLAN bindings, new services, Authentik, WikiJS, Tailscale) |
| `nginx-proxy-manager-guide.md` | NPM reverse proxy setup, Cloudflare/Let's Encrypt TLS, all proxy host configurations |
| `tools-v2-guide.md` | Tools stack v2 deployment (pgAdmin, Stirling PDF, Mealie) |
| `tools-v3-guide.md` | Tools stack v3 deployment (n8n, IT Tools) |
| `tools-v4-guide.md` | Tools stack v4 deployment (Actual Budget, Paperless-ngx, Grocy) |
| `tools-v5-guide.md` | Tools stack v5 deployment (Linkwarden, Backrest) |
| `media-gaming-v3-guide.md` | Media-gaming stack v3 deployment (Audiobookshelf, Kavita) |
| `dashboards-automation-v3-guide.md` | Dashboards-automation stack v3 deployment (Loki, Promtail) |
| `infrastructure-networking-v3-guide.md` | Infrastructure-networking stack v3 deployment (CrowdSec) |
| `llm-stack-guide.md` | Local LLM stack setup (Ollama + Open WebUI), model management, air-gapped operation |
| `compose-review-notes.md` | Rationale for compose file changes, deferred Postgres migration procedure |

------------------------------------------------------------------------

## Stacks

| Stack | Services |
|-------|----------|
| `dashboards-automation` | Homepage, Home Assistant, Uptime Kuma, Grafana, Prometheus — v3 adds Loki, Promtail |
| `dockge` | Dockge |
| `infrastructure-networking` | Pi-hole, Nginx Proxy Manager, Watchtower, ntfy, Tailscale — v3 adds CrowdSec |
| `media-gaming` | AMP, Immich, Immich Machine Learning, Jellyfin — v3 adds Audiobookshelf, Kavita |
| `auth` | Authentik, PostgreSQL, Redis |
| `tools` | WikiJS, PostgreSQL — v2 adds pgAdmin, Stirling PDF, Mealie; v3 adds n8n, IT Tools; v4 adds Actual Budget, Paperless-ngx, Grocy; v5 adds Linkwarden, Backrest |
| `llm` | Ollama, Open WebUI |

`compose.yaml` files are the current deployed state. `compose.v2.yaml`
files are the migration target for each stack. The `auth`, `tools`, and
`llm` stacks have no v1 -- `compose.yaml` is the initial deployment for
each.

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
| pgAdmin | `tools` | 5050 | `pgadmin.home.bremmer.zone` | PostgreSQL web admin (v2) |
| Stirling PDF | `tools` | 8083 | `pdf.home.bremmer.zone` | PDF tools (v2) |
| Mealie | `tools` | 9925 | `mealie.home.bremmer.zone` | Recipe manager (v2) |
| n8n | `tools` | 5678 | `n8n.home.bremmer.zone` | Workflow automation (v3) |
| IT Tools | `tools` | 8084 | `it-tools.home.bremmer.zone` | Developer utilities (v3) |
| Actual Budget | `tools` | 5006 | `budget.home.bremmer.zone` | Personal finance (v4) |
| Paperless-ngx | `tools` | 8085 | `paperless.home.bremmer.zone` | Document management (v4) |
| Paperless PostgreSQL | `tools` | — | — | Paperless database (v4, internal) |
| Paperless Redis | `tools` | — | — | Paperless queue (v4, internal) |
| Grocy | `tools` | 9283 | `grocy.home.bremmer.zone` | Household management (v4) |
| Linkwarden | `tools` | 3005 | `links.home.bremmer.zone` | Bookmark manager with page archiving (v5) |
| Linkwarden PostgreSQL | `tools` | — | — | Linkwarden database (v5, internal) |
| Backrest | `tools` | 9898 | `backrest.home.bremmer.zone` | Restic backup UI, backs up to NAS (v5) |
| Audiobookshelf | `media-gaming` | 13378 | `abs.home.bremmer.zone` | Audiobooks and podcasts (v3) |
| Kavita | `media-gaming` | 5000 | `kavita.home.bremmer.zone` | Ebook and comic reader (v3) |
| Loki | `dashboards-automation` | 3100 | — | Log aggregation, queried from Grafana (v3, internal) |
| Promtail | `dashboards-automation` | — | — | Log collector, ships to Loki (v3, internal) |
| CrowdSec | `infrastructure-networking` | — | — | Intrusion detection, reads NPM logs (v3, internal) |
| Ollama | `llm` | 11434 | — | LLM inference API |
| Open WebUI | `llm` | 3004 | `llm.home.bremmer.zone` | Chat interface |

------------------------------------------------------------------------

## Directory Structure

All stacks are stored under `/opt/docker/stacks/` on the host:

``` text
/opt/docker/stacks/
├── dashboards-automation/
│   ├── compose.yaml             # Current deployed
│   ├── compose.v2.yaml          # Migration target
│   ├── .env                     # Grafana password
│   ├── prometheus/config/       # prometheus.yml (copy from repo)
│   └── homepage/config/
│
├── dockge/
│   └── compose.yaml
│
├── infrastructure-networking/
│   ├── compose.yaml             # Current deployed
│   ├── compose.v2.yaml          # Migration target
│   ├── .env                     # Pi-hole password, Tailscale auth key, ntfy topic
│   ├── pihole/config/
│   ├── pihole/dnsmasq/
│   └── npm/
│
├── media-gaming/
│   ├── compose.yaml             # Current deployed
│   ├── compose.v2.yaml          # Migration target
│   ├── .env                     # Immich database credentials
│   ├── amp/datastore/
│   ├── immich/postgres/         # Keep on NVMe
│   ├── immich/redis/
│   ├── immich/cache/
│   ├── immich/model-cache/
│   └── jellyfin/
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
│   ├── compose.yaml             # Current deployed (WikiJS + PostgreSQL)
│   ├── compose.v2.yaml          # Adds pgAdmin, Stirling PDF, Mealie
│   ├── compose.v3.yaml          # Adds n8n, IT Tools
│   ├── compose.v4.yaml          # Adds Actual Budget, Paperless-ngx, Audiobookshelf, Grocy, Kavita
│   ├── .env                     # Stack credentials (gitignored)
│   ├── postgres/                # WikiJS database data
│   ├── pgadmin/                 # pgAdmin data (v2+)
│   ├── stirling-pdf/            # Stirling PDF config and OCR data (v2+)
│   ├── mealie/                  # Mealie recipe data (v2+)
│   ├── n8n/                     # n8n workflow data (v3+)
│   ├── actual-budget/           # Actual Budget data (v4+)
│   ├── paperless/               # Paperless-ngx data, media, postgres, redis (v4+)
│   ├── audiobookshelf/          # Audiobookshelf config and metadata (v4+)
│   ├── compose.v5.yaml          # Adds Linkwarden, Backrest
│   ├── grocy/                   # Grocy config (v4+)
│   ├── linkwarden/              # Linkwarden data and postgres (v5+)
│   └── backrest/                # Backrest config and metadata (v5+)
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

`compose.v3.yaml` adds Loki and Promtail. See `dashboards-automation-v3-guide.md`.

**Ports (v3 full state)**

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
```

**Notes**

-   Prometheus requires `./prometheus/config/prometheus.yml` to exist
    before starting. Copy it from `docker/dashboards-automation/prometheus/prometheus.yml`
    in the repository.
-   node-exporter runs with `network_mode: host` for accurate system
    metrics. Prometheus reaches it via `host.docker.internal:9100`.
-   Grafana's Prometheus data source URL (configured post-deploy):
    `http://prometheus:9090`
-   Loki (v3) requires config files copied from the repo before
    deploying. After deploy, add Loki as a Grafana data source at
    `http://loki:3100`. See `dashboards-automation-v3-guide.md`.

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

`compose.v3.yaml` adds CrowdSec. See `infrastructure-networking-v3-guide.md`.

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
    `./pihole/dnsmasq/02-local-dns.conf`. See `nginx-proxy-manager-guide.md`.
-   Remote access is provided by Tailscale. No port forwarding is
    required. See the v2 setup guide for auth key generation.
-   Watchtower uses ntfy for update notifications. Set
    `WATCHTOWER_NTFY_TOPIC` to the topic name you subscribe to in the
    ntfy app (e.g. `watchtower`).
-   Watchtower only updates containers with the label
    `com.centurylinklabs.watchtower.enable=true`.
-   CrowdSec (v3) reads NPM logs from `./npm/logs` and detects attack
    patterns. Requires the firewall bouncer installed on the host to
    act on decisions. See `infrastructure-networking-v3-guide.md`.

------------------------------------------------------------------------

### media-gaming

`compose.v3.yaml` adds Audiobookshelf and Kavita. See `media-gaming-v3-guide.md`.

**Ports (v3 full state)**

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
    Adjust the volume mount in `compose.v2.yaml` if your NAS path
    differs.
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
not change the image tag in-place. See `compose-review-notes.md` for
the procedure.

------------------------------------------------------------------------

### tools

Four versioned compose files. `compose.yaml` is the current deployed
state. Deploy each version in order to migrate forward -- each version
is a complete, standalone compose file that includes all prior services.

| Version | Adds |
|---------|------|
| `compose.v2.yaml` | pgAdmin, Stirling PDF, Mealie |
| `compose.v3.yaml` | n8n, IT Tools |
| `compose.v4.yaml` | Actual Budget, Paperless-ngx, Grocy |
| `compose.v5.yaml` | Linkwarden, Backrest |

**Ports (v4 full state)**

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
# v1
DB_USER=wikijs
DB_PASS=
DB_NAME=wikijs
VLAN11_IP=192.168.11.10
# v2
PGADMIN_EMAIL=
PGADMIN_PASSWORD=
# v3
N8N_ENCRYPTION_KEY=
# v4
PAPERLESS_DB_USER=
PAPERLESS_DB_PASS=
PAPERLESS_SECRET_KEY=
```

Generate `N8N_ENCRYPTION_KEY` and `PAPERLESS_SECRET_KEY` with:

``` bash
openssl rand -hex 32
```

**Notes**

-   WikiJS supports OIDC authentication via Authentik. Configure this
    post-deploy in the WikiJS admin panel to enable single sign-on.
-   WikiJS PostgreSQL is isolated from all other PostgreSQL containers
    in the stack. Paperless-ngx has its own dedicated PostgreSQL and
    Redis containers.
-   Paperless-ngx: drop files into `./paperless/consume` to ingest
    documents automatically.
-   Audiobookshelf and Kavita mount from NAS at
    `/mnt/synology/audiobooks`, `/mnt/synology/podcasts`, and
    `/mnt/synology/books`. Create these directories on the NAS before
    deploying v4.
-   n8n webhook URL is configured for `https://n8n.home.bremmer.zone`.
    The NPM proxy host must exist before webhooks will work.
-   Backrest mounts `/opt/docker/stacks` read-only and
    `/mnt/synology/backups` as the backup destination. Create the NAS
    directory before deploying v5.

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
    See `llm-stack-guide.md` for model recommendations and pull
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

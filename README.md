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

## Stacks

| Stack | Services |
|-------|----------|
| `dashboards-automation` | Homepage, Home Assistant, Uptime Kuma, Grafana, Prometheus |
| `dockge` | Dockge |
| `infrastructure-networking` | Pi-hole, Nginx Proxy Manager, Watchtower, ntfy, Tailscale |
| `media-gaming` | AMP, Immich, Immich Machine Learning, Jellyfin |
| `auth` | Authentik, PostgreSQL, Redis |
| `tools` | WikiJS, PostgreSQL |

`compose.yaml` files are the current deployed state. `compose.v2.yaml`
files are the migration target for each stack. The `auth` stack has no
v1 -- `compose.yaml` is its initial deployment.

------------------------------------------------------------------------

## Service Quick Reference

All hosted services, their stack, access port, and purpose at a glance.
Internal-only services (no exposed port) are marked with a dash.

| Service | Stack | Port | Purpose |
|---------|-------|------|---------|
| Homepage | `dashboards-automation` | 3000 | Service dashboard |
| Home Assistant | `dashboards-automation` | 8123 | Home automation |
| Uptime Kuma | `dashboards-automation` | 3001 | Uptime monitoring |
| Grafana | `dashboards-automation` | 3002 | Metrics dashboards |
| Prometheus | `dashboards-automation` | 9090 | Metrics collection |
| node-exporter | `dashboards-automation` | 9100 | Host system metrics (host network) |
| Dockge | `dockge` | 5001 | Docker stack manager |
| Nginx Proxy Manager | `infrastructure-networking` | 80 / 443 / 81 (admin) | Reverse proxy and SSL |
| Pi-hole | `infrastructure-networking` | 53 (DNS), 8080 (web) | Network-wide DNS filtering |
| Watchtower | `infrastructure-networking` | — | Automated container updates |
| ntfy | `infrastructure-networking` | 8082 | Push notifications |
| Tailscale | `infrastructure-networking` | — | Remote access (host network) |
| AMP | `media-gaming` | 8081 | Game server management |
| Immich | `media-gaming` | 2283 | Photo and video library |
| Immich Machine Learning | `media-gaming` | — | Smart search and face recognition (internal) |
| Immich PostgreSQL | `media-gaming` | — | Immich database (internal) |
| Immich Redis | `media-gaming` | — | Immich job queue (internal) |
| Jellyfin | `media-gaming` | 8096 | Media server |
| Authentik | `auth` | 9000 / 9443 (HTTPS) | Single sign-on and identity provider |
| Authentik PostgreSQL | `auth` | — | Authentik database (internal) |
| Authentik Redis | `auth` | — | Authentik cache (internal) |
| WikiJS | `tools` | 3003 | Internal wiki and documentation |
| WikiJS PostgreSQL | `tools` | — | WikiJS database (internal) |

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
└── tools/
    ├── compose.yaml             # WikiJS and its PostgreSQL instance
    ├── .env                     # WikiJS database credentials (gitignored)
    └── postgres/                # WikiJS database data
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

**Ports**

| Service | Port |
|---------|------|
| Homepage | 3000 |
| Home Assistant | 8123 |
| Uptime Kuma | 3001 |
| Grafana | 3002 |
| Prometheus | 9090 |
| node-exporter | 9100 (host network) |

**Environment file** -- `./dashboards-automation/.env`

``` text
GRAFANA_PASSWORD=
VLAN11_IP=
```

**Notes**

-   Prometheus requires `./prometheus/config/prometheus.yml` to exist
    before starting. Copy it from `docker/dashboards-automation/prometheus/prometheus.yml`
    in the repository.
-   node-exporter runs with `network_mode: host` for accurate system
    metrics. Prometheus reaches it via `host.docker.internal:9100`.
-   Grafana's Prometheus data source URL (configured post-deploy):
    `http://prometheus:9090`

------------------------------------------------------------------------

### dockge

**Ports**

| Service | Port |
|---------|------|
| Dockge | 5001 |

Manages stacks at `/opt/docker/stacks` on the host.

------------------------------------------------------------------------

### infrastructure-networking

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
VLAN11_IP=
```

**Notes**

-   Remote access is provided by Tailscale. No port forwarding is
    required. See the setup guide for auth key generation.
-   Watchtower uses ntfy for update notifications. Set
    `WATCHTOWER_NTFY_TOPIC` to the topic name you subscribe to in the
    ntfy app (e.g. `watchtower`).
-   Watchtower only updates containers with the label
    `com.centurylinklabs.watchtower.enable=true`.

------------------------------------------------------------------------

### media-gaming

**Ports**

| Service | Port |
|---------|------|
| AMP | 8081 |
| Minecraft (example) | 25565 |
| Immich | 2283 |
| Jellyfin | 8096 |

**Environment file** -- `./media-gaming/.env`

``` text
DB_USERNAME=
DB_PASSWORD=
DB_DATABASE_NAME=
VLAN61_IP=
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

**Ports**

| Service | Port |
|---------|------|
| WikiJS | 3003 |

**Environment file** -- `./tools/.env`

``` text
DB_USER=wikijs
DB_PASS=
DB_NAME=wikijs
VLAN11_IP=
```

**Notes**

-   WikiJS supports OIDC authentication via Authentik. Configure this
    post-deploy in the WikiJS admin panel to enable single sign-on.
-   Initial admin account is created through the browser on first start.
-   WikiJS and its PostgreSQL instance are isolated from the auth
    stack's PostgreSQL.

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
VLAN11_IP=
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

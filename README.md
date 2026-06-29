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

## Directory Structure

All stacks are stored under:

``` text
/opt/docker/
├── dashboards-automation/
│   ├── compose.yaml             # Homepage and Home Assistant
│   └── homepage/config/         # Dashboard configuration
│
├── dockge/
│   ├── compose.yaml             # Dockge stack manager
│   └── data/                    # Dockge application data
│
├── infrastructure-networking/
│   ├── compose.yaml             # Pi-hole, Nginx Proxy Manager, Watchtower
│   ├── pihole/config/           # Pi-hole persistent configuration
│   ├── pihole/dnsmasq/          # Local DNS rules
│   └── npm/                     # Proxy Manager data and certificates
│
└── media-gaming/
    ├── compose.yaml             # AMP and Immich services
    ├── .env                     # Database credentials
    ├── amp/datastore/           # Game server data
    └── immich/                  # Immich cache and database
```

Dockge manages stacks at `/opt/docker/stacks` on the host.

------------------------------------------------------------------------

# Deployment

Deploy stacks in the following order. `dashboards-automation` must come
first because it creates the shared `proxy_net` Docker network that all
other stacks attach to.

## Prerequisites

### Disable systemd-resolved

Pi-hole requires direct access to port 53.

``` bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

### Mount Synology Storage

Ensure NFS shares are permanently mounted through `/etc/fstab`.

Example:

``` text
/mnt/synology/immich
```

------------------------------------------------------------------------

## 1. Dashboards & Automation Stack

Location:

``` bash
/opt/docker/dashboards-automation/
```

Deploy first -- this stack creates the `proxy_net` network used by all
other stacks.

``` bash
docker compose up -d
```

Services:

-   **Homepage**
    -   Local service dashboard
    -   Available on port `3000`
-   **Home Assistant**
    -   Home automation platform
    -   Available on port `8123`

------------------------------------------------------------------------

## 2. Dockge

Location:

``` bash
/opt/docker/dockge/
```

Deploy:

``` bash
docker compose up -d
```

Services:

-   **Dockge**
    -   Docker Compose management interface
    -   Access at:

        ``` text
        http://<mini-pc-ip>:5001
        ```

    -   Manages stacks stored under `/opt/docker/stacks`

------------------------------------------------------------------------

## 3. Infrastructure & Networking Stack

Location:

``` bash
/opt/docker/infrastructure-networking/
```

Deploy:

``` bash
docker compose up -d
```

Services:

-   **Pi-hole**
    -   Network-wide DNS filtering
    -   Web interface available on port `8080`
    -   Requires port 53 (TCP and UDP) for DNS
-   **Nginx Proxy Manager**
    -   Handles HTTP/HTTPS routing and SSL termination
    -   Admin interface available on port `81`
    -   HTTP on port `80`, HTTPS on port `443`
-   **Watchtower**
    -   Automated container image updates
    -   Polls every 24 hours (`86400` seconds)
    -   Cleans up old images after updates

------------------------------------------------------------------------

## 4. Media & Gaming Stack

Location:

``` bash
/opt/docker/media-gaming/
```

Deploy:

``` bash
docker compose up -d
```

Services:

-   **AMP**
    -   Game server management platform
    -   Management UI available on port `8081`
    -   Example: Minecraft server on port `25565`
-   **Immich**
    -   Photo and video management platform
    -   Available on port `2283`
    -   Uses Intel Quick Sync (`/dev/dri`) for hardware transcoding
    -   Backed by PostgreSQL with vector search (`pgvecto-rs`) and Redis

### Storage Notes

The Immich PostgreSQL database must remain on local SSD storage.

Recommended:

-   Database (`./immich/postgres`) → Mini PC NVMe storage
-   Media uploads (`/mnt/synology/immich`) → Synology NAS mount

This avoids database performance issues caused by network latency.

### Environment Variables

The media-gaming stack requires a `.env` file with:

``` text
DB_USERNAME=
DB_PASSWORD=
DB_DATABASE_NAME=
```

------------------------------------------------------------------------

# Maintenance

## View Logs

Using Dockge:

-   Open the stack
-   Select the service
-   View live logs

CLI alternative:

``` bash
docker compose logs -f <service_name>
```

## Backup Strategy

Back up:

-   Docker Compose files
-   Configuration directories
-   Version-controlled infrastructure files

Exclude:

-   Database files (`./immich/postgres`)
-   `.env` secrets
-   Temporary application data

Recommended:

-   Use Synology Hyper Backup for media and asset protection

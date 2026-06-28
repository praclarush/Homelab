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
~/docker/
├── network/
│   ├── docker-compose.yml       # Pi-hole and Nginx Proxy Manager
│   ├── etc-pihole/              # Pi-hole persistent configuration
│   ├── etc-dnsmasq.d/            # Local DNS rules
│   └── npm/                     # Proxy Manager data and certificates
│
├── management/
│   ├── docker-compose.yml       # Dockge, Homepage, Watchtower
│   ├── dockge/                  # Dockge stack data
│   └── homepage/config/         # Dashboard configuration
│
├── media/
│   ├── docker-compose.yml       # AMP and Immich services
│   ├── .env                     # Environment secrets
│   ├── amp/datastore/           # Game server data
│   └── immich/                  # Immich application data
│
└── automation/
    ├── docker-compose.yml       # Home Assistant
    └── config/                  # Home Assistant YAML configuration
```

------------------------------------------------------------------------

# Deployment

Deploy stacks in the following order.

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

## 1. Network Stack

Location:

``` bash
~/docker/network/
```

Deploy:

``` bash
docker compose up -d
```

Services:

-   **Pi-hole**
    -   Provides network-wide DNS filtering
    -   Web interface available on port `8080`
-   **Nginx Proxy Manager**
    -   Handles HTTP/HTTPS routing
    -   Admin interface available on port `81`

------------------------------------------------------------------------

## 2. Management Stack

Location:

``` bash
~/docker/management/
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
-   **Homepage**
    -   Local service dashboard on port `3000`
-   **Watchtower**
    -   Performs automated container image updates

------------------------------------------------------------------------

## 3. Media & Gaming Stack

Location:

``` bash
~/docker/media/
```

Deploy:

``` bash
docker compose up -d
```

Services:

-   **AMP**
    -   Game server management
    -   Example: Minecraft on port `25565`
-   **Immich**
    -   Photo management platform
    -   Uses PostgreSQL with vector search support

### Storage Notes

The Immich database must remain on local SSD storage.

Recommended:

-   Database → Mini PC NVMe storage
-   Media uploads → Synology NAS mount

This avoids database performance issues caused by network latency.

------------------------------------------------------------------------

## 4. Automation Stack

Location:

``` bash
~/docker/automation/
```

Deploy:

``` bash
docker compose up -d
```

Services:

-   **Home Assistant**
    -   Runs using `network_mode: host`
    -   Enables automatic discovery across the local network

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

-   Database files
-   `.env` secrets
-   Temporary application data

Recommended:

-   Use Synology Hyper Backup for media and asset protection

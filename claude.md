# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Infrastructure-as-code for a Docker Compose homelab. No application code, no build pipeline, no tests. The authoritative deployment target is `/opt/docker/` on the Linux host.

## Common Commands

All operations are standard Docker Compose, run from within a stack directory:

```bash
docker compose up -d          # Start stack
docker compose down           # Stop stack
docker compose pull           # Update images
docker compose logs -f        # Follow logs
docker compose logs -f <svc>  # Follow a single service
```

## Architecture

Four stacks under `docker/`:

| Stack | Services |
|-------|----------|
| `dashboards-automation` | Homepage (3000), Home Assistant (8123) |
| `dockge` | Dockge stack manager (5001) |
| `infrastructure-networking` | Pi-hole (8080/53), Nginx Proxy Manager (80/81/443), Watchtower |
| `media-gaming` | AMP (8081/25565), Immich (2283), Postgres, Redis |

### Shared Network Dependency

`proxy_net` is a Docker bridge network created by `dashboards-automation` (`external: false`). The `infrastructure-networking` and `media-gaming` stacks join it as `external: true`. **`dashboards-automation` must be running before those two stacks can start.**

`dockge` is standalone and has no network dependency.

### Dockge Stack Path

Dockge is configured to manage stacks at `/opt/docker/stacks` (set via `DOCKGE_STACKS_DIR`). This must match the actual path on the host where compose files are stored.

### Immich Storage Split

Immich splits storage intentionally: the PostgreSQL data directory (`./immich/postgres`) stays on local NVMe, while the media upload volume mounts from the Synology NAS at `/mnt/synology/immich`. Combining them onto NFS causes database performance issues.

### Pi-hole Port Conflict

Pi-hole binds to port 53. `systemd-resolved` must be stopped and disabled on the host before the `infrastructure-networking` stack will start cleanly.

## Secrets and Gitignore

`.env` files are gitignored. The `media-gaming` stack requires a `.env` alongside its `compose.yaml` with:

```
DB_USERNAME=
DB_PASSWORD=
DB_DATABASE_NAME=
```

All generated runtime data (databases, caches, logs, certificates) is gitignored. Only `compose.yaml` files and static configuration belong in version control.

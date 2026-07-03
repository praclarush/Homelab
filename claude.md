# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Infrastructure-as-code for a Docker Compose homelab. No application code, no build pipeline, no tests. The authoritative deployment target is `/opt/docker/` on the Linux host.

The repository root holds two parallel snapshots of the same homelab:

- **`V2/`** -- the current state, and what the rest of this file describes. Each stack has a single `compose.yaml`; there is no version history to reconcile within it.
- **`V1/`** -- the prior, versioned snapshot, preserved for history. Several stacks there carry multiple `compose.vN.yaml` files representing incremental migrations (e.g. `tools/compose.yaml` through `compose.v5.yaml`). Do not add new work to `V1/`.

## Common Commands

All operations are standard Docker Compose, run from within a stack directory under `V2/stacks/`:

```bash
docker compose up -d          # Start stack
docker compose down           # Stop stack
docker compose pull           # Update images
docker compose logs -f        # Follow logs
docker compose logs -f <svc>  # Follow a single service
```

## Architecture

Seven stacks under `V2/stacks/`. Each stack has a single `compose.yaml` -- the current, deployable state.

| Stack | Services |
|-------|----------|
| `dashboards-automation` | Homepage (3000), Home Assistant (8123), Uptime Kuma (3001), Grafana (3002), Prometheus (9090), node-exporter (host), Loki (3100), Promtail |
| `dockge` | Dockge stack manager (5001) |
| `infrastructure-networking` | Pi-hole (8080/53), Nginx Proxy Manager (80/81/443), Watchtower, ntfy (8082), Tailscale (host), CrowdSec |
| `media-gaming` | AMP (8081), Immich (2283), Immich Machine Learning, Postgres, Redis, Jellyfin (8096), Audiobookshelf (13378), Kavita (5000) |
| `auth` | Authentik (9000/9443), Postgres, Redis |
| `tools` | WikiJS (3003), Postgres, pgAdmin (5050), Stirling PDF (8083), Mealie (9925), n8n (5678), IT Tools (8084), Actual Budget (5006), Paperless-ngx (8085), Paperless Postgres, Paperless Redis, Grocy (9283), Linkwarden (3005), Linkwarden Postgres, Backrest (9898) |
| `llm` | Ollama (11434), Open WebUI (3004) |

## VLAN Bindings

The host mini PC has two VLAN interfaces. Services bind their host ports to the correct VLAN IP via `.env` variables. `V2/guides/networking/vlan-reference.md` is the source of truth for the full home-network VLAN plan (9 VLANs); only these two are relevant to this repo:

| Variable | Value | VLAN | Services |
|----------|-------|------|----------|
| `VLAN11_IP` | `192.168.11.10` | VLAN 11 (Services) | All management and dashboard services |
| `VLAN61_IP` | `192.168.61.10` | VLAN 61 (NAS) | Immich, Jellyfin, AMP, Audiobookshelf, Kavita -- bound here for same-subnet NFS access to the Synology NAS, which also lives on VLAN 61 |

`VLAN61_IP=192.168.61.10` must be reserved in Ubiquiti before deploying `media-gaming`. VLAN 61 is a newly created VLAN.

## Proxy Domain

All services with web interfaces are proxied through Nginx Proxy Manager at `*.home.bremmer.zone`. TLS certificates are issued via Let's Encrypt DNS-01 challenge using Cloudflare. Pi-hole resolves `*.home.bremmer.zone` internally to `192.168.11.10` via a dnsmasq wildcard entry at `/opt/docker/stacks/infrastructure-networking/pihole/dnsmasq/02-local-dns.conf`.

## Shared Network Dependency

`proxy_net` is a Docker bridge network created by `dashboards-automation` (`external: false`). All other stacks except `dockge` join it as `external: true`. **`dashboards-automation` must be running before any other stack starts.**

`dockge` is standalone with no `networks:` configuration -- it is not on `proxy_net` and cannot be reached by container name from NPM. NPM proxies Dockge via the host IP (`192.168.11.10:5001`).

## Key Architecture Notes

**Dockge stack path:** Configured to manage stacks at `/opt/docker/stacks` via `DOCKGE_STACKS_DIR`. This must match the actual path on the host.

**`/opt/docker/stacks` is a symlink, not a plain directory:** Per `V2/guides/operations/git-deployment-guide.md`, it resolves to `/opt/docker/repo/stacks`, a clone of this repository's remote. Compose and Dockge both follow the symlink transparently. Config changes made directly on the host are committed and pushed from `/opt/docker/repo`; changes pushed elsewhere are pulled there and applied with `docker compose up -d` in the affected stack directory.

**Immich storage split:** PostgreSQL data (`./immich/postgres`) stays on local NVMe. Media uploads mount from NAS at `/mnt/synology/immich`. Do not move the database to NFS.

**Pi-hole port conflict:** Pi-hole binds to port 53. `systemd-resolved` must be stopped and disabled before the `infrastructure-networking` stack starts.

**node-exporter:** Runs with `network_mode: host` and `pid: host`. Prometheus reaches it via `host.docker.internal:9100` using the `extra_hosts` entry in the Prometheus service.

**Immich Postgres image:** Currently on `tensorchord/pgvecto-rs:pg14-v0.2.0`. Needs migration to `ghcr.io/immich-app/postgres:14-vectorchord0.3.0-pgvectors0.2.0` via dump/restore at a maintenance window. Do not change the image tag in-place. See `V2/stacks/compose-review-notes.md`.

**LLM inference is CPU-only:** The mini PC uses Intel UHD integrated graphics. Ollama's GPU acceleration requires NVIDIA or AMD hardware. All inference runs on CPU. Model size ceiling is ~14B parameters (Q4 quantized, ~9 GB) given 16 GB total system RAM. Do not suggest models above 14B for this hardware.

## Secrets and Gitignore

`.env` files are gitignored. Required `.env` contents per stack:

| Stack | Required Variables |
|-------|-------------------|
| `dashboards-automation` | `GRAFANA_PASSWORD`, `VLAN11_IP`, `HOMEPAGE_VAR_IMMICH_KEY`, `HOMEPAGE_VAR_JELLYFIN_KEY`, `HOMEPAGE_VAR_PIHOLE_KEY` |
| `dockge` | `VLAN11_IP` |
| `infrastructure-networking` | `PIHOLE_PASSWORD`, `TAILSCALE_AUTHKEY`, `WATCHTOWER_NTFY_TOPIC`, `VLAN11_IP` |
| `media-gaming` | `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE_NAME`, `VLAN61_IP` |
| `auth` | `PG_USER`, `PG_PASS`, `PG_DB`, `AUTHENTIK_SECRET_KEY`, `VLAN11_IP` |
| `tools` | `DB_USER`, `DB_PASS`, `DB_NAME`, `VLAN11_IP`, `PGADMIN_EMAIL`, `PGADMIN_PASSWORD`, `N8N_ENCRYPTION_KEY`, `PAPERLESS_DB_USER`, `PAPERLESS_DB_PASS`, `PAPERLESS_SECRET_KEY`, `LINKWARDEN_DB_USER`, `LINKWARDEN_DB_PASS`, `LINKWARDEN_SECRET` (Grocy needs no `.env` entries -- its `PUID`/`PGID`/`TZ` are set directly in `compose.yaml`) |
| `llm` | `VLAN11_IP` |

All generated runtime data (databases, caches, logs, certificates) is gitignored. Only `compose.yaml` files and static configuration belong in version control.

## Documentation

`V2/guides/` is organized like a wiki (it will eventually move into the WikiJS
stack): `V2/guides/README.md` is the index page. See it for the full,
categorized list. Quick reference:

| File | Purpose |
|------|---------|
| `README.md` | Stack reference, service inventory, env file contents, deployment order |
| `V2/guides/getting-started/homelab-guide.md` | Full setup guide: Linux basics, prerequisites, NordVPN Meshnet remote access, and initial deployment of all six core stacks |
| `V2/guides/networking/nginx-proxy-manager-guide.md` | NPM reverse proxy setup, Cloudflare/Let's Encrypt TLS, all proxy host configurations |
| `V2/guides/networking/pihole-guide.md` | Pi-hole deployment, network-wide DNS handoff, local/wildcard DNS records, blocklist and Teleporter maintenance |
| `V2/guides/operations/git-deployment-guide.md` | Cloning this repo onto the Ubuntu Server host as a live git working tree, gitignore correctness, and the push/pull workflow for config changes |
| `V2/guides/stacks/tools-guide.md` | `tools` stack beyond WikiJS: pgAdmin, Stirling PDF, Mealie, n8n, IT Tools, Actual Budget, Paperless-ngx, Grocy, Linkwarden, Backrest |
| `V2/guides/stacks/media-gaming-guide.md` | `media-gaming` stack beyond AMP and Immich: Jellyfin, Audiobookshelf, Kavita |
| `V2/guides/stacks/dashboards-automation-guide.md` | `dashboards-automation` stack beyond Homepage, Home Assistant, Uptime Kuma, Grafana, Prometheus: Loki, Promtail |
| `V2/guides/stacks/infrastructure-networking-guide.md` | `infrastructure-networking` stack beyond NPM, Pi-hole, Watchtower, ntfy, Tailscale: CrowdSec |
| `V2/guides/stacks/llm-stack-guide.md` | Local LLM stack setup (Ollama + Open WebUI), model management, air-gapped operation |
| `V2/stacks/compose-review-notes.md` | Rationale for compose file changes, deferred Postgres migration procedure |
| `V2/config/README.md` | Complete reference copies of host-level Linux configs (`/etc/fstab`, Netplan, CrowdSec bouncer) that live outside `V2/stacks/` |

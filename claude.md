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

Seven stacks under `docker/`. Each stack has a `compose.yaml` (current deployed state) and where noted a `compose.v2.yaml` (migration target with VLAN bindings, new services, and additional configuration). The `auth`, `tools`, and `llm` stacks have no v1 -- `compose.yaml` is the initial deployment for each.

| Stack | Services |
|-------|----------|
| `dashboards-automation` | Homepage (3000), Home Assistant (8123), Uptime Kuma (3001), Grafana (3002), Prometheus (9090), node-exporter (host) |
| `dockge` | Dockge stack manager (5001) |
| `infrastructure-networking` | Pi-hole (8080/53), Nginx Proxy Manager (80/81/443), Watchtower, ntfy (8082), Tailscale (host) |
| `media-gaming` | AMP (8081), Immich (2283), Jellyfin (8096), Postgres, Redis |
| `auth` | Authentik (9000/9443), Postgres, Redis |
| `tools` | WikiJS (3003), Postgres — v2: pgAdmin (5050), Stirling PDF (8083), Mealie (9925) — v3: n8n (5678), IT Tools (8084) — v4: Actual Budget (5006), Paperless-ngx (8085), Audiobookshelf (13378), Grocy (9283), Kavita (5000) |
| `llm` | Ollama (11434), Open WebUI (3004) |

## VLAN Bindings

The host mini PC has two VLAN interfaces. Services bind their host ports to the correct VLAN IP via `.env` variables:

| Variable | Value | VLAN | Services |
|----------|-------|------|----------|
| `VLAN11_IP` | `192.168.11.10` | VLAN 11 (Services) | All management and dashboard services |
| `VLAN61_IP` | `192.168.61.10` | VLAN 61 (Media) | Immich, Jellyfin, AMP |

`VLAN61_IP=192.168.61.10` must be reserved in Ubiquiti before deploying `media-gaming` v2. VLAN 61 is newly created.

## Proxy Domain

All services with web interfaces are proxied through Nginx Proxy Manager at `*.home.bremmer.zone`. TLS certificates are issued via Let's Encrypt DNS-01 challenge using Cloudflare. Pi-hole resolves `*.home.bremmer.zone` internally to `192.168.11.10` via a dnsmasq wildcard entry at `/opt/docker/stacks/infrastructure-networking/pihole/dnsmasq/02-local-dns.conf`.

## Shared Network Dependency

`proxy_net` is a Docker bridge network created by `dashboards-automation` (`external: false`). All other stacks except `dockge` join it as `external: true`. **`dashboards-automation` must be running before any other stack starts.**

`dockge` is standalone with no `networks:` configuration -- it is not on `proxy_net` and cannot be reached by container name from NPM. NPM proxies Dockge via the host IP (`192.168.11.10:5001`).

## Key Architecture Notes

**Dockge stack path:** Configured to manage stacks at `/opt/docker/stacks` via `DOCKGE_STACKS_DIR`. This must match the actual path on the host.

**Immich storage split:** PostgreSQL data (`./immich/postgres`) stays on local NVMe. Media uploads mount from NAS at `/mnt/synology/immich`. Do not move the database to NFS.

**Pi-hole port conflict:** Pi-hole binds to port 53. `systemd-resolved` must be stopped and disabled before the `infrastructure-networking` stack starts.

**node-exporter:** Runs with `network_mode: host` and `pid: host`. Prometheus reaches it via `host.docker.internal:9100` using the `extra_hosts` entry in the Prometheus service.

**Immich Postgres image:** Currently on `tensorchord/pgvecto-rs:pg14-v0.2.0`. Needs migration to `ghcr.io/immich-app/postgres:14-vectorchord0.3.0-pgvectors0.2.0` via dump/restore at a maintenance window. Do not change the image tag in-place. See `compose-review-notes.md`.

**LLM inference is CPU-only:** The mini PC uses Intel UHD integrated graphics. Ollama's GPU acceleration requires NVIDIA or AMD hardware. All inference runs on CPU. Model size ceiling is ~14B parameters (Q4 quantized, ~9 GB) given 16 GB total system RAM. Do not suggest models above 14B for this hardware.

## Secrets and Gitignore

`.env` files are gitignored. Required `.env` contents per stack:

| Stack | Required Variables |
|-------|-------------------|
| `dashboards-automation` | `GRAFANA_PASSWORD`, `VLAN11_IP` |
| `dockge` | `VLAN11_IP` |
| `infrastructure-networking` | `PIHOLE_PASSWORD`, `TAILSCALE_AUTHKEY`, `WATCHTOWER_NTFY_TOPIC`, `VLAN11_IP` |
| `media-gaming` | `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE_NAME`, `VLAN61_IP` |
| `auth` | `PG_USER`, `PG_PASS`, `PG_DB`, `AUTHENTIK_SECRET_KEY`, `VLAN11_IP` |
| `tools` | `DB_USER`, `DB_PASS`, `DB_NAME`, `VLAN11_IP` — v2 adds: `PGADMIN_EMAIL`, `PGADMIN_PASSWORD` — v3 adds: `N8N_ENCRYPTION_KEY` — v4 adds: `PAPERLESS_DB_USER`, `PAPERLESS_DB_PASS`, `PAPERLESS_SECRET_KEY` |
| `llm` | `VLAN11_IP` |

All generated runtime data (databases, caches, logs, certificates) is gitignored. Only `compose.yaml` files and static configuration belong in version control.

## Documentation

| File | Purpose |
|------|---------|
| `README.md` | Stack reference, service inventory, env file contents, deployment order |
| `homelab-v1-configuration-guide.md` | Step-by-step setup guide for v1 stacks (Linux basics, prerequisites, initial deployment) |
| `homelab-v2-configuration-guide.md` | Migration guide from v1 to v2 (VLAN bindings, new services, Authentik, WikiJS, Tailscale) |
| `nginx-proxy-manager-guide.md` | NPM reverse proxy setup, Cloudflare/Let's Encrypt TLS, all proxy host configurations |
| `llm-stack-guide.md` | Local LLM stack setup (Ollama + Open WebUI), model management, air-gapped operation |
| `compose-review-notes.md` | Rationale for compose file changes, deferred Postgres migration procedure |

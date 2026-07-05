# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Infrastructure-as-code for a Docker Compose homelab. No application code, no tests -- but `.github/workflows/` does run CI: `validate-compose.yaml` runs `docker compose config -q` against every stack on any PR/push touching `Docker/stacks/**`, and `lint-scripts.yaml` runs ShellCheck and PSScriptAnalyzer against `Scripts/**`. The authoritative deployment target is `/opt/docker/` on the Linux host.

See [README.md's "Repository Layout" section](README.md#repository-layout) for the top-level folder breakdown (`Docker/`, `Guides/`, `Migrations/`, `Scripts/`) -- that's the canonical copy; update it, not this file, if the layout changes. `Docker/` holds the current, deployed state, and what most of the rest of this file describes.

## Common Commands

All operations are standard Docker Compose, run from within a stack directory under `Docker/stacks/`:

```bash
docker compose up -d          # Start stack
docker compose down           # Stop stack
docker compose pull           # Update images
docker compose logs -f        # Follow logs
docker compose logs -f <svc>  # Follow a single service
```

Before considering a `compose.yaml` edit done, run `docker compose config -q` from that stack's directory -- this is what CI checks. Before considering a `Scripts/` edit done, run `shellcheck` on any changed `.sh` file (or PSScriptAnalyzer for `.ps1`) -- same as `lint-scripts.yaml`.

## Migrations Conventions

- **Versioning**: `Migrations/V3/` is a batch of items blocked on hardware or another external dependency, staged toward a future major version. `Migrations/V2.1/` is a batch of minor, low-risk updates to the *currently-deployed* production state (historically called "V2" -- versioned `V1`/`V2` folders existed before being collapsed into today's `Docker/` layout; see git history around commit `d92985e`). Bump the minor version for further low-risk production updates; only start a new major-version batch for changes blocked on hardware or another external dependency, matching the `V3` pattern.
- **Full drop-in replacements**: when a migration item replaces an entire stack's `compose.yaml` rather than adding one service for hand-merging, name its subfolder after the target stack (e.g. `infrastructure-networking/`), not a generic `compose/` folder, and say explicitly in that item's `README.md` that the file is a complete copy of the current `compose.yaml` with the new service appended. Diff it against the live file before promoting -- it can go stale if the live file changes after the migration was written.
- Every item is still self-contained with its own `README.md`: What This Is / What's In This Folder / Setup / Verify / Promotion, matching the existing `V3/` items.

## Architecture

Seven stacks under `Docker/stacks/`. Each stack has a single `compose.yaml` -- the current, deployable state.

| Stack | Services |
|-------|----------|
| `dashboards-automation` | Homepage (3000), Home Assistant (8123), Uptime Kuma (3001), Grafana (3002), Prometheus (9090), node-exporter (host), Loki (3100), Promtail |
| `dockge` | Dockge stack manager (5001) |
| `infrastructure-networking` | Pi-hole (8080/53), Nginx Proxy Manager (80/81/443), Watchtower, ntfy (8082), Tailscale (host), CrowdSec |
| `media-gaming` | AMP (8081), Immich (2283), Immich Machine Learning, Postgres, Postgres Backup, Redis, Jellyfin (8096), Audiobookshelf (13378), Kavita (5000) |
| `auth` | Authentik (9000/9443), Postgres, Postgres Backup, Redis |
| `tools` | WikiJS (3003), Postgres, Postgres Backup, pgAdmin (5050), Stirling PDF (8083), Mealie (9925), n8n (5678), IT Tools (8084), Actual Budget (5006), Paperless-ngx (8085), Paperless Postgres, Paperless Postgres Backup, Paperless Redis, Grocy (9283), Linkwarden (3005), Linkwarden Postgres, Linkwarden Postgres Backup, Backrest (9898) |
| `llm` | Ollama (11434), Open WebUI (3004) |

## VLAN Bindings

The host mini PC has two VLAN interfaces. Services bind their host ports to the correct VLAN IP via `.env` variables. `Guides/networking/vlan-reference.md` is the source of truth for the full home-network VLAN plan (9 VLANs); only these two are relevant to this repo:

| Variable | Value | VLAN | Services |
|----------|-------|------|----------|
| `VLAN11_IP` | `192.168.11.10` | VLAN 11 (Services) | All management and dashboard services |
| `VLAN61_IP` | `192.168.61.10` | VLAN 61 (NAS) | Immich, Jellyfin, AMP, Audiobookshelf, Kavita -- bound here for same-subnet NFS access to the Synology NAS, which also lives on VLAN 61 |

`VLAN61_IP=192.168.61.10` must be reserved in Ubiquiti before deploying `media-gaming`. VLAN 61 is a newly created VLAN.

## Proxy Domain

All services with web interfaces are proxied through Nginx Proxy Manager at `*.home.bremmer.zone`. TLS certificates are issued via Let's Encrypt DNS-01 challenge using Cloudflare. Pi-hole resolves `*.home.bremmer.zone` internally to `192.168.11.10` via a dnsmasq wildcard entry at `/opt/docker/stacks/infrastructure-networking/pihole/dnsmasq/02-local-dns.conf`.

## Shared Network Dependency

`proxy_net` is a Docker bridge network created by `infrastructure-networking` (`external: false`). All other stacks except `dockge` join it as `external: true`. **`infrastructure-networking` must be running before any other stack starts.**

`dockge` is standalone with no `networks:` configuration -- it is not on `proxy_net` and cannot be reached by container name from NPM. NPM proxies Dockge via the host IP (`192.168.11.10:5001`).

## Key Architecture Notes

**Dockge stack path:** Configured to manage stacks at `/opt/docker/stacks` via `DOCKGE_STACKS_DIR`. This must match the actual path on the host.

**`/opt/docker/stacks` is a symlink, not a plain directory:** Per `Guides/operations/git-deployment-guide.md`, it resolves to `/srv/git/homelab/Docker/stacks`, a clone of this repository's remote kept in a dedicated repos folder separate from `/opt/docker`. Compose and Dockge both follow the symlink transparently. Config changes made directly on the host are committed and pushed from `/srv/git/homelab`; changes pushed elsewhere are pulled there and applied with `docker compose up -d` in the affected stack directory.

**Immich storage split:** PostgreSQL data (`./immich/postgres`) stays on local NVMe. Media uploads mount from NAS at `/mnt/synology/immich`. Do not move the database to NFS.

**Pi-hole port conflict:** Pi-hole binds to port 53. `systemd-resolved` must be stopped and disabled before the `infrastructure-networking` stack starts.

**node-exporter:** Runs with `network_mode: host` and `pid: host`. Prometheus reaches it via `host.docker.internal:9100` using the `extra_hosts` entry in the Prometheus service.

**Immich Postgres image:** On `ghcr.io/immich-app/postgres:14-vectorchord0.4.2-pgvectors0.2.0`, migrated from `tensorchord/pgvecto-rs:pg14-v0.2.0` after Immich v3.0.1 dropped pgvecto.rs support. See `Docker/stacks/compose-review-notes.md` for the migration record.

**LLM inference is CPU-only:** The mini PC uses Intel UHD integrated graphics. Ollama's GPU acceleration requires NVIDIA or AMD hardware. All inference runs on CPU. Model size ceiling is ~14B parameters (Q4 quantized, ~9 GB) given 16 GB total system RAM. Do not suggest models above 14B for this hardware.

## Secrets and Gitignore

`.env` files are gitignored. Required `.env` contents per stack:

| Stack | Required Variables |
|-------|-------------------|
| `dashboards-automation` | `GRAFANA_PASSWORD`, `VLAN11_IP`, `HOMEPAGE_VAR_IMMICH_KEY`, `HOMEPAGE_VAR_JELLYFIN_KEY`, `HOMEPAGE_VAR_PIHOLE_KEY` |
| `dockge` | `VLAN11_IP` |
| `infrastructure-networking` | `PIHOLE_PASSWORD`, `TAILSCALE_AUTHKEY`, `WATCHTOWER_NTFY_TOPIC`, `WATCHTOWER_NTFY_PASS`, `VLAN11_IP` |
| `media-gaming` | `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE_NAME`, `VLAN61_IP` |
| `auth` | `PG_USER`, `PG_PASS`, `PG_DB`, `AUTHENTIK_SECRET_KEY`, `VLAN11_IP` |
| `tools` | `DB_USER`, `DB_PASS`, `DB_NAME`, `VLAN11_IP`, `PGADMIN_EMAIL`, `PGADMIN_PASSWORD`, `N8N_ENCRYPTION_KEY`, `PAPERLESS_DB_USER`, `PAPERLESS_DB_PASS`, `PAPERLESS_SECRET_KEY`, `LINKWARDEN_DB_USER`, `LINKWARDEN_DB_PASS`, `LINKWARDEN_SECRET` (Grocy needs no `.env` entries -- its `PUID`/`PGID`/`TZ` are set directly in `compose.yaml`) |
| `llm` | `VLAN11_IP` |

All generated runtime data (databases, caches, logs, certificates) is gitignored. Only `compose.yaml` files and static configuration belong in version control.

## Documentation

`Guides/` is organized like a wiki (it will eventually move into the WikiJS
stack): `Guides/README.md` is the index page. See it for the full,
categorized list. Quick reference:

| File | Purpose |
|------|---------|
| `README.md` | Repo overview, service/port inventory, directory layout, deployment order pointer |
| `Guides/getting-started/homelab-guide.md` | Full setup guide: Linux basics, prerequisites, NordVPN Meshnet remote access, and initial deployment of all six core stacks |
| `Guides/networking/nginx-proxy-manager-guide.md` | NPM reverse proxy setup, Cloudflare/Let's Encrypt TLS, all proxy host configurations |
| `Guides/networking/pihole-guide.md` | Pi-hole deployment, network-wide DNS handoff, local/wildcard DNS records, blocklist and Teleporter maintenance |
| `Guides/operations/git-deployment-guide.md` | Cloning this repo onto the Ubuntu Server host as a live git working tree, gitignore correctness, and the push/pull workflow for config changes |
| `Guides/stacks/tools-guide.md` | `tools` stack beyond WikiJS: pgAdmin, Stirling PDF, Mealie, n8n, IT Tools, Actual Budget, Paperless-ngx, Grocy, Linkwarden, Backrest |
| `Guides/stacks/media-gaming-guide.md` | `media-gaming` stack beyond AMP and Immich: Jellyfin, Audiobookshelf, Kavita |
| `Guides/stacks/dashboards-automation-guide.md` | `dashboards-automation` stack beyond Homepage, Home Assistant, Uptime Kuma, Grafana, Prometheus: Loki, Promtail |
| `Guides/stacks/infrastructure-networking-guide.md` | `infrastructure-networking` stack beyond NPM, Pi-hole, ntfy, Tailscale: CrowdSec, and the cross-stack Watchtower auto-update policy |
| `Guides/stacks/llm-stack-guide.md` | Local LLM stack setup (Ollama + Open WebUI), model management, air-gapped operation, cross-stack `mem_limit`/OOM-killer rationale |
| `Docker/stacks/compose-review-notes.md` | Rationale for compose file changes, including the completed Immich Postgres image migration |
| `Docker/config/README.md` | Complete reference copies of host-level Linux configs (`/etc/fstab`, Netplan, CrowdSec bouncer) that live outside `Docker/stacks/` |

## Branching

Root branches are `master` and `release` only. Every other branch must be prefixed `{kind}/{branchName}`:

| Kind | Use |
|------|-----|
| `bug/` | Non-urgent bug fixes -- the affected stack is degraded but not restart-looping |
| `hotfix/` | Urgent fixes for an issue actively affecting a running stack right now |
| `task/` | Everything else -- features, docs, refactors, migrations |

`release` is tagged at each release point using `major.minor.patch` semantic versioning. A `hotfix/` is always a patch bump.

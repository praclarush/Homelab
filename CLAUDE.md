# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Infrastructure-as-code for a Docker Compose homelab. No application code, no tests -- but `.github/workflows/` does run CI: `validate-compose.yaml` runs `docker compose config -q` against every stack on any PR/push touching `Docker/stacks/**`, and `lint-scripts.yaml` runs ShellCheck and PSScriptAnalyzer against `Scripts/**`. The authoritative deployment target is `/opt/docker/stacks/` on the Linux host.

See [README.md's "Repository Layout" section](README.md#repository-layout) for the top-level folder breakdown (`Docker/`, `Migrations/`, `Scripts/`) -- that's the canonical copy; update it, not this file, if the layout changes. `Docker/` holds the current, deployed state, and what most of the rest of this file describes.

How-to guides are authored in the separate [`praclarush/Homelab-wiki`](https://github.com/praclarush/Homelab-wiki) repo, git-synced into the WikiJS instance (`tools` stack, `https://wiki.home.example.com`). This repo has no `Guides/` folder -- new or updated documentation belongs in `Homelab-wiki`, not here. See its [Documentation](#documentation) entry below.

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

- **Versioning**: `Migrations/V3/` is a batch of items blocked on hardware or another external dependency, staged toward a future major version. A versioned `Migrations/V2.x/` folder (e.g. the now-fully-promoted `V2.1/`, historically called "V2" -- versioned `V1`/`V2` folders existed before being collapsed into today's `Docker/` layout; see git history around commit `837b8b3`) holds a batch of minor, low-risk updates to the *currently-deployed* production state, created fresh whenever there's a new one to stage and removed once every item in it is promoted. Bump the minor version for further low-risk production updates; only start a new major-version batch for changes blocked on hardware or another external dependency, matching the `V3` pattern.
- **Full drop-in replacements**: when a migration item replaces an entire stack's `compose.yaml` rather than adding one service for hand-merging, name its subfolder after the target stack (e.g. `infrastructure-networking/`), not a generic `compose/` folder, and say explicitly in that item's `README.md` that the file is a complete copy of the current `compose.yaml` with the new service appended. Diff it against the live file before promoting -- it can go stale if the live file changes after the migration was written.
- Every item is still self-contained with its own `README.md`: What This Is / What's In This Folder / Setup / Verify / Promotion, matching the existing `V3/` items.

## Architecture

Seven stacks under `Docker/stacks/`. Each stack has a single `compose.yaml` -- the current, deployable state.

| Stack | Services |
|-------|----------|
| `dashboards-automation` | Homepage (3000), Home Assistant (8123), Uptime Kuma (3001), Grafana (3002), Prometheus (9090), node-exporter (host), Loki (3100), Promtail, nut-exporter (9995, internal) |
| `dockge` | Dockge stack manager (5001) |
| `infrastructure-networking` | Pi-hole (8080/53), Nginx Proxy Manager (80/81/443), Watchtower, ntfy (8082), Tailscale (host), CrowdSec, Postfix Relay (25) |
| `media-gaming` | AMP (8081), Immich (2283), Immich Machine Learning, Postgres, Postgres Backup, Redis, Jellyfin (8096), Audiobookshelf (13378), Kavita (5000), Dispatcharr (9191) |
| `auth` | Authentik (9000/9443), Postgres, Postgres Backup, Redis |
| `tools` | WikiJS (3003), Postgres, Postgres Backup, pgAdmin (5050), Stirling PDF (8083), Mealie (9925), n8n (5678), IT Tools (8084), Actual Budget (5006), Paperless-ngx (8085), Paperless Postgres, Paperless Postgres Backup, Paperless Redis, Grocy (9283), Linkwarden (3005), Linkwarden Postgres, Linkwarden Postgres Backup, Backrest (9898) |
| `llm` | Ollama (11434), Open WebUI (3004) |

## VLAN Bindings

The host mini PC has two VLAN interfaces. Services bind their host ports to the correct VLAN IP via `.env` variables. [`networking/vlan-reference.md`](https://github.com/praclarush/Homelab-wiki/blob/master/networking/vlan-reference.md) in the `Homelab-wiki` repo is the source of truth for the full home-network VLAN plan (9 VLANs); only these two are relevant to this repo:

| Variable | Value | VLAN | Services |
|----------|-------|------|----------|
| `VLAN11_IP` | `192.168.11.10` | VLAN 11 (Services) | All management and dashboard services, plus Dispatcharr in `media-gaming` -- it has no NAS/NFS traffic, only internet-facing IPTV sources and container-name traffic to Jellyfin over `proxy_net` |
| `VLAN61_IP` | `192.168.61.10` | VLAN 61 (NAS) | Immich, Jellyfin, AMP, Audiobookshelf, Kavita -- bound here for same-subnet NFS access to the Synology NAS, which also lives on VLAN 61 |

`VLAN61_IP=192.168.61.10` must be reserved in Ubiquiti before deploying `media-gaming`. VLAN 61 is a newly created VLAN.

## Meshnet Bindings

The host also runs NordVPN Meshnet (`nordlynx` interface) for remote access to select services without exposing them publicly or routing a paired device's entire traffic through the house -- Meshnet's "route all traffic through this device" mode has no split-tunnel/subnet-only option (unlike Tailscale's subnet routers), so it's only suitable for all-or-nothing full-gateway access. For scoped access to individual services instead, those services additionally bind to `MESHNET_IP` (the host's own Meshnet address) alongside their normal VLAN binding, the same pattern as `VLAN11_IP`/`VLAN61_IP`:

| Variable | Value | Services bound here |
|----------|-------|----------------------|
| `MESHNET_IP` | `100.124.229.64` | `ntfy` (`infrastructure-networking`), `wikijs` + `mealie` + `paperless-ngx` + `grocy` (`tools`), `homeassistant` (`dashboards-automation`), `immich-server` + `jellyfin` + `audiobookshelf` + `kavita` (`media-gaming`) |

This is opt-in per service, not a blanket default like `VLAN11_IP` -- only add it to a service that's intentionally meant to be reachable from a paired Meshnet device (e.g. a phone off the home network), since some services (database admin UIs, tools with no login of their own) shouldn't be remotely reachable without more thought first.

## Proxy Domain

All services with web interfaces are proxied through Nginx Proxy Manager at `*.home.example.com`. TLS certificates are issued via Let's Encrypt DNS-01 challenge using Cloudflare. Pi-hole resolves `*.home.example.com` internally to `192.168.11.10` via a dnsmasq wildcard entry at `/opt/docker/stacks/infrastructure-networking/pihole/dnsmasq/02-local-dns.conf`.

## Shared Network Dependency

`proxy_net` is a Docker bridge network created by `infrastructure-networking` (`external: false`). All other stacks except `dockge` join it as `external: true`. **`infrastructure-networking` must be running before any other stack starts.**

`dockge` is standalone with no `networks:` configuration -- it is not on `proxy_net` and cannot be reached by container name from NPM. NPM proxies Dockge via the host IP (`192.168.11.10:5001`).

## Key Architecture Notes

**Dockge stack path:** Configured to manage stacks at `/opt/docker/stacks` via `DOCKGE_STACKS_DIR`. This must match the actual path on the host.

**`/opt/docker/stacks` is a symlink, not a plain directory:** Per [`operations/git-deployment-guide.md`](https://github.com/praclarush/Homelab-wiki/blob/master/operations/git-deployment-guide.md) in the `Homelab-wiki` repo, it resolves to `/srv/git/homelab/Docker/stacks`, a clone of this repository's remote kept in a dedicated repos folder separate from `/opt/docker`. Compose and Dockge both follow the symlink transparently. Config changes made directly on the host are committed and pushed from `/srv/git/homelab`; changes pushed elsewhere are pulled there and applied with `docker compose up -d` in the affected stack directory.

**Immich storage split:** PostgreSQL data (`./immich/postgres`) stays on local NVMe. Media uploads mount from NAS at `/mnt/synology/immich`. Do not move the database to NFS.

**Pi-hole port conflict:** Pi-hole binds to port 53. `systemd-resolved` must be stopped and disabled before the `infrastructure-networking` stack starts.

**node-exporter:** Runs with `network_mode: host` and `pid: host`. Prometheus reaches it via `host.docker.internal:9100` using the `extra_hosts` entry in the Prometheus service.

**nut-exporter:** Unlike every other exporter in this stack, what it exports (NUT/`upsd`) isn't a container at all -- it's a bare-metal systemd service on the host monitoring a USB-attached UPS (see `Homelab-wiki/hardware-configuration/cyberpower-cp1500pfcrm2u-ups-guide.md`). `nut-exporter` reaches it via `host.docker.internal:3493` using the same `extra_hosts` pattern as node-exporter/Prometheus, and `/etc/nut/upsd.conf` must have `LISTEN 0.0.0.0 3493` (not just localhost) on the host for that connection to succeed -- this is a host-level config change outside `Docker/stacks/`, not something this repo can enforce.

**Immich Postgres image:** On `ghcr.io/immich-app/postgres:14-vectorchord0.4.2-pgvectors0.2.0`, migrated from `tensorchord/pgvecto-rs:pg14-v0.2.0` after Immich v3.0.1 dropped pgvecto.rs support.

**LLM inference is CPU-only:** The mini PC uses Intel UHD integrated graphics. Ollama's GPU acceleration requires NVIDIA or AMD hardware. All inference runs on CPU. Model size ceiling is ~14B parameters (Q4 quantized, ~9 GB) given 16 GB total system RAM. Do not suggest models above 14B for this hardware.

## Secrets and Gitignore

`.env` files are gitignored. Required `.env` contents per stack:

| Stack | Required Variables |
|-------|-------------------|
| `dashboards-automation` | `GRAFANA_PASSWORD`, `VLAN11_IP`, `MESHNET_IP`, `DOMAIN`, `HOMEPAGE_VAR_IMMICH_KEY`, `HOMEPAGE_VAR_JELLYFIN_KEY`, `HOMEPAGE_VAR_PIHOLE_KEY` |
| `dockge` | `VLAN11_IP` |
| `infrastructure-networking` | `PIHOLE_PASSWORD`, `TAILSCALE_AUTHKEY`, `WATCHTOWER_NTFY_TOPIC`, `WATCHTOWER_NTFY_PASS`, `VLAN11_IP`, `MESHNET_IP`, `DOMAIN`, `SMTP_RELAY_USERNAME`, `SMTP_RELAY_PASSWORD` |
| `media-gaming` | `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE_NAME`, `VLAN61_IP`, `VLAN11_IP`, `MESHNET_IP` |
| `auth` | `PG_USER`, `PG_PASS`, `PG_DB`, `AUTHENTIK_SECRET_KEY`, `VLAN11_IP` |
| `tools` | `DB_USER`, `DB_PASS`, `DB_NAME`, `VLAN11_IP`, `MESHNET_IP`, `DOMAIN`, `PGADMIN_EMAIL`, `PGADMIN_PASSWORD`, `N8N_ENCRYPTION_KEY`, `PAPERLESS_DB_USER`, `PAPERLESS_DB_PASS`, `PAPERLESS_SECRET_KEY`, `LINKWARDEN_DB_USER`, `LINKWARDEN_DB_PASS`, `LINKWARDEN_SECRET` (Grocy needs no `.env` entries -- its `PUID`/`PGID`/`TZ` are set directly in `compose.yaml`) |
| `llm` | `VLAN11_IP` |

All generated runtime data (databases, caches, logs, certificates) is gitignored. Only `compose.yaml` files and static configuration belong in version control.

## Documentation

Guides are authored in the separate [`praclarush/Homelab-wiki`](https://github.com/praclarush/Homelab-wiki)
repo, git-synced into the WikiJS instance (`tools` stack,
`https://wiki.home.example.com`). Create or edit guides there, not here.
Start at [its README.md](https://github.com/praclarush/Homelab-wiki/blob/master/README.md)
for the full, categorized list. Quick reference:

| File | Purpose |
|------|---------|
| `README.md` (this repo) | Repo overview, service/port inventory, directory layout, deployment order pointer |
| `Homelab-wiki/getting-started/homelab-guide.md` | Full setup guide: Linux basics, prerequisites, NordVPN Meshnet remote access, and initial deployment of all six core stacks |
| `Homelab-wiki/networking/nginx-proxy-manager-guide.md` | NPM reverse proxy setup, Cloudflare/Let's Encrypt TLS, all proxy host configurations |
| `Homelab-wiki/networking/pihole-guide.md` | Pi-hole deployment, network-wide DNS handoff, local/wildcard DNS records, blocklist and Teleporter maintenance |
| `Homelab-wiki/networking/authentik-guide.md` | Authentik admin bootstrap, domain-level forward auth for no-login services, per-service OIDC/OAuth2 SSO setup for every service that supports it, and which services are intentionally excluded |
| `Homelab-wiki/operations/git-deployment-guide.md` | Cloning this repo onto the Ubuntu Server host as a live git working tree, gitignore correctness, and the push/pull workflow for config changes |
| `Homelab-wiki/stacks/tools-guide.md` | `tools` stack beyond WikiJS: pgAdmin, Stirling PDF, Mealie, n8n, IT Tools, Actual Budget, Paperless-ngx, Grocy, Linkwarden, Backrest |
| `Homelab-wiki/stacks/media-gaming-guide.md` | `media-gaming` stack beyond AMP and Immich: Jellyfin, Audiobookshelf, Kavita |
| `Homelab-wiki/stacks/dashboards-automation-guide.md` | `dashboards-automation` stack beyond Homepage, Home Assistant, Uptime Kuma, Grafana, Prometheus: Loki, Promtail, nut-exporter |
| `Homelab-wiki/hardware-configuration/cyberpower-cp1500pfcrm2u-ups-guide.md` | Host-level UPS monitoring with NUT: USB/udev setup, automatic shutdown on power loss, ntfy alerts, and the Prometheus/Grafana metrics wiring for `nut-exporter` |
| `Homelab-wiki/stacks/infrastructure-networking-guide.md` | `infrastructure-networking` stack beyond NPM, Pi-hole, ntfy, Tailscale: CrowdSec, and the cross-stack Watchtower auto-update policy |
| `Homelab-wiki/stacks/llm-stack-guide.md` | Local LLM stack setup (Ollama + Open WebUI), model management, air-gapped operation, cross-stack `mem_limit`/OOM-killer rationale |
| `Docker/config/README.md` | Complete reference copies of host-level Linux configs (`/etc/fstab`, Netplan, CrowdSec bouncer) that live outside `Docker/stacks/` |

## Branching

Root branches are `master` and `release` only. Both are protected -- no direct pushes; the only way code moves into either is via Pull Request. (GitHub-side branch protection rules are not yet enforced on the `praclarush/Homelab` remote -- the private repo is on the free plan, which doesn't support the branch protection API. Enforce this by convention until the repo is public or upgraded to Pro.)

Every other branch must be prefixed `{kind}/{branchName}`:

| Kind | Use |
|------|-----|
| `bug/` | Non-urgent bug fixes -- the affected stack is degraded but not restart-looping |
| `hotfix/` | Urgent fixes for an issue actively affecting a running stack right now |
| `task/` | Everything else -- features, docs, refactors, migrations |

`release` is tagged at each release point using `major.minor.patch` semantic versioning. A `hotfix/` is always a patch bump, and is always branched from and merged back into `release` first, then forward-merged (or cherry-picked) into `master`.

Every tag must be an annotated tag (`git tag -a`, not lightweight) with a description covering the probable cause of the release -- what prompted it, not just the version number. For a `hotfix/` batch, list each fix bundled into it with its PR number; for a regular release, summarize the notable changes since the last tag the same way. A bare `git tag v2.1.2` with no `-m`/`-F` message is incomplete -- `git tag -l -n99 <tag>` should always explain why the tag exists.

### GitHub Issues

Every issue filed against this repo (not just hotfix issues, see below) must be created with:

- **Project**: added to the `Homelab` GitHub Project.
- **Label**: matching the relevant `.github/ISSUE_TEMPLATE/*.yml` template's default label (e.g. `bug` for a bug report, `enhancement` for a stack change) -- `gh issue create` picks this up automatically from the template, but set it explicitly when creating issues via `gh issue create --label` directly.
- **Assignee**: `praclarush`.

```bash
gh issue create --label bug --assignee praclarush --project "Homelab" --title "..." --body "..."
```

### GitHub Pull Requests

Every PR opened against this repo must be created with the same three, set at creation time rather than added after the fact:

- **Project**: added to the `Homelab` GitHub Project.
- **Label**: from the same taxonomy as issues, chosen by what the PR itself changes (`bug` for a fix, `enhancement` for a new feature/script, `documentation` for docs-only), not necessarily the label of the issue it closes.
- **Assignee**: `praclarush`.

```bash
gh pr create --label enhancement --assignee praclarush --project "Homelab" --base master --head <branch> --title "..." --body "..."
```

### Hotfix Workflow

Any change made directly to a stack's `compose.yaml` on the live host (i.e. in `/opt/docker/stacks/`, which is `/srv/git/homelab/Docker/stacks` on the host) is a hotfix by default, unless the user says otherwise -- the host is production, so an edit made there means something on it is broken right now.

Hotfixes land in a batch branch, not directly against `release`:

1. **Batch branch**: `hotfix/V{major.minor.patch}`, branched from `release`, incrementing the patch version from the latest tag on `release` (e.g. latest tag `v2.1.0` -> batch branch `hotfix/V2.1.1`). If a batch branch for the next patch version is already open, target it instead of creating a new one -- retarget any existing hotfix PRs still pointed at `release` onto it.
2. **Per-fix branch**: for each individual hotfix, branch off the batch branch (not `release` directly), named `hotfix/{description}`. Apply the fix, commit, and open a PR targeting the batch branch. File a GitHub issue for the bug if one doesn't already exist, and close it from the PR.
3. Once every per-fix PR is merged into the batch branch, merge the batch branch into `release` and tag the new patch version with an annotated tag describing the fixes bundled into it (see [Branching](#branching)).
4. Forward-merge (or cherry-pick) `release` into `master`.

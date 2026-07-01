# Homelab Guides

This is the index page for the homelab's documentation. The guides below are
organized into four categories, the same way they will eventually be laid
out once this content moves into the WikiJS instance (`tools` stack) running
on the homelab itself.

Each guide is self-contained and assumes you are comfortable with general
Windows IT concepts (networking, DNS, services, ports, credentials) but may
be new to Linux and the command line. Where a guide depends on something
covered earlier (a VLAN being configured, a stack already being deployed),
it says so explicitly and points back to the specific section.

For the service inventory, port list, and `.env` file reference, see the
[repository root README](../README.md) instead -- it is the quick-reference
doc, not a how-to guide.

For a complete reference copy of the host-level Linux config files these
guides have you edit (`/etc/fstab`, Netplan, the CrowdSec bouncer config)
see [`config/`](../config/README.md) -- it's a reference companion to the
guides below, not a guide on its own.

---

## Recommended Reading Order (New Deployment)

If you are standing this homelab up from scratch, read in this order:

1. [Getting Started](getting-started/homelab-guide.md) -- everything needed to bring up all six core stacks
2. [Networking: Nginx Proxy Manager](networking/nginx-proxy-manager-guide.md) -- give every service a clean HTTPS domain
3. [Networking: Pi-hole](networking/pihole-guide.md) -- the DNS guide that NPM's wildcard domain depends on (read alongside step 2)
4. [Operations: Git Deployment](operations/git-deployment-guide.md) -- turn the live deployment into a git working tree so config changes are tracked
5. Whichever guides under [Stacks](#stacks) match the additional services you want next

If you are instead picking up an existing deployment to add one new service,
skip straight to the relevant guide under **Stacks**.

---

## Getting Started

| Guide | Covers |
|-------|--------|
| [homelab-guide.md](getting-started/homelab-guide.md) | Linux-from-Windows basics, all prerequisites (port 53, base NFS mounts, Intel Quick Sync, VLAN trunking), NordVPN Meshnet remote access, secrets generation, and first deployment of `dashboards-automation`, `dockge`, `infrastructure-networking`, `media-gaming`, `auth`, and `tools` |

## Networking

Deep-dive reference guides for the network, reverse proxy, and DNS layer.
Used for initial setup and as an ongoing reference (adding proxy hosts,
managing blocklists, certificate renewal, looking up a VLAN).

| Guide | Covers |
|-------|--------|
| [vlan-reference.md](networking/vlan-reference.md) | Complete VLAN ID/subnet/purpose reference sheet for the whole home network, not just the homelab |
| [nginx-proxy-manager-guide.md](networking/nginx-proxy-manager-guide.md) | Cloudflare DNS setup, Let's Encrypt wildcard certificate, every proxy host configuration, troubleshooting (502s, cert errors) |
| [pihole-guide.md](networking/pihole-guide.md) | Network-wide DNS handoff, local DNS records, the wildcard record backing the proxy domain, blocklist (gravity) management, Teleporter backup/restore |

## Operations

Ongoing, cross-stack maintenance -- not tied to a specific stack.

| Guide | Covers |
|-------|--------|
| [git-deployment-guide.md](operations/git-deployment-guide.md) | Turning the live `/opt/docker/stacks` deployment into a git working tree, keeping `.gitignore` correct, day-to-day push/pull workflow, and what to check when adding a new stack or service |

## Stacks

Per-stack guides covering services beyond what the getting-started guide
already deploys. Each assumes the base stack (deployed in Getting Started)
is already running.

| Guide | Covers |
|-------|--------|
| [tools-guide.md](stacks/tools-guide.md) | `tools` stack beyond WikiJS: pgAdmin, Stirling PDF, Mealie, n8n, IT Tools, Actual Budget, Paperless-ngx, Grocy, Linkwarden, Backrest |
| [media-gaming-guide.md](stacks/media-gaming-guide.md) | `media-gaming` stack beyond AMP and Immich: Jellyfin, Audiobookshelf, Kavita |
| [dashboards-automation-guide.md](stacks/dashboards-automation-guide.md) | `dashboards-automation` stack beyond Homepage, Home Assistant, Uptime Kuma, Grafana, and Prometheus: Loki and Promtail (log aggregation) |
| [infrastructure-networking-guide.md](stacks/infrastructure-networking-guide.md) | `infrastructure-networking` stack beyond NPM, Pi-hole, Watchtower, ntfy, and Tailscale: CrowdSec intrusion detection |
| [llm-stack-guide.md](stacks/llm-stack-guide.md) | `llm` stack (Ollama + Open WebUI): deployment, model management, air-gapped operation |

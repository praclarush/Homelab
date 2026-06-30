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

---

## Recommended Reading Order (New Deployment)

If you are standing this homelab up from scratch, read in this order:

1. [Getting Started: v1](getting-started/homelab-v1-guide.md) -- everything needed to bring up the first four stacks
2. [Getting Started: v2](getting-started/homelab-v2-guide.md) -- VLANs, remote access, and the `auth`/`tools` stacks
3. [Networking: Nginx Proxy Manager](networking/nginx-proxy-manager-guide.md) -- once v2 is up, give every service a clean HTTPS domain
4. [Networking: Pi-hole](networking/pihole-guide.md) -- the DNS guide that NPM's wildcard domain depends on (read alongside step 3)
5. [Operations: Git Deployment](operations/git-deployment-guide.md) -- turn the live deployment into a git working tree so config changes are tracked
6. Whichever guides under [Stacks](#stacks) match the services you want next

If you are instead picking up an existing deployment to add one new service,
skip straight to the relevant guide under **Stacks**.

---

## Getting Started

Initial environment buildout. Read these in order; v2 assumes v1 is already running.

| Guide | Covers |
|-------|--------|
| [homelab-v1-guide.md](getting-started/homelab-v1-guide.md) | Linux-from-Windows basics, prerequisites (port 53, NFS mounts, Intel Quick Sync, VLAN trunking), and first deployment of `dashboards-automation`, `dockge`, `infrastructure-networking`, and `media-gaming` |
| [homelab-v2-guide.md](getting-started/homelab-v2-guide.md) | VLAN migration, NordVPN Meshnet remote access, secrets generation, and first deployment of the `auth` and `tools` stacks |

## Networking

Deep-dive reference guides for the reverse proxy and DNS layer. Used for
initial setup and as an ongoing reference (adding proxy hosts, managing
blocklists, certificate renewal).

| Guide | Covers |
|-------|--------|
| [nginx-proxy-manager-guide.md](networking/nginx-proxy-manager-guide.md) | Cloudflare DNS setup, Let's Encrypt wildcard certificate, every proxy host configuration, troubleshooting (502s, cert errors) |
| [pihole-guide.md](networking/pihole-guide.md) | Network-wide DNS handoff, local DNS records, the wildcard record backing the proxy domain, blocklist (gravity) management, Teleporter backup/restore |

## Operations

Ongoing, cross-stack maintenance -- not tied to a specific stack or version.

| Guide | Covers |
|-------|--------|
| [git-deployment-guide.md](operations/git-deployment-guide.md) | Turning the live `/opt/docker/stacks` deployment into a git working tree, keeping `.gitignore` correct, day-to-day push/pull workflow, and what to check when adding a new stack or service |

## Stacks

Per-stack deployment and version-upgrade guides. Each one assumes the
previous version of that same stack is already running.

| Guide | Covers |
|-------|--------|
| [tools-v2-guide.md](stacks/tools-v2-guide.md) | `tools` stack v2: pgAdmin, Stirling PDF, Mealie |
| [tools-v3-guide.md](stacks/tools-v3-guide.md) | `tools` stack v3: n8n, IT Tools |
| [tools-v4-guide.md](stacks/tools-v4-guide.md) | `tools` stack v4: Actual Budget, Paperless-ngx |
| [tools-v5-guide.md](stacks/tools-v5-guide.md) | `tools` stack v5: Linkwarden, Backrest |
| [media-gaming-v3-guide.md](stacks/media-gaming-v3-guide.md) | `media-gaming` stack v3: Audiobookshelf, Kavita |
| [dashboards-automation-v3-guide.md](stacks/dashboards-automation-v3-guide.md) | `dashboards-automation` stack v3: Loki, Promtail (log aggregation) |
| [infrastructure-networking-v3-guide.md](stacks/infrastructure-networking-v3-guide.md) | `infrastructure-networking` stack v3: CrowdSec intrusion detection |
| [llm-stack-guide.md](stacks/llm-stack-guide.md) | `llm` stack (Ollama + Open WebUI): deployment, model management, air-gapped operation |

---

## A Note on Versioned Compose Files

Several stacks have more than one `compose.vN.yaml` file in the repository
(under `stacks/<stack-name>/`). `compose.yaml` is always the version
currently deployed on the host. Each `compose.vN.yaml` is a complete,
standalone file -- it is not a diff or patch, it includes every service from
every prior version plus the new ones. Migrating forward means replacing
`compose.yaml` with the next version's file and re-running
`docker compose up -d`, exactly as each stack guide above describes.

# Tools Stack v5 Guide

This guide deploys the v5 migration of the `tools` stack, adding
Linkwarden and Backrest to the existing v4 deployment.

> **Prerequisite:** The `tools` stack must be running on `compose.v4.yaml`
> before migrating to v5.

---

## Contents

1. [What v5 Adds](#1-what-v5-adds)
2. [Update the Environment File](#2-update-the-environment-file)
3. [Deploy v5](#3-deploy-v5)
4. [Configure Nginx Proxy Manager](#4-configure-nginx-proxy-manager)
5. [First-Time Service Setup](#5-first-time-service-setup)
6. [Verification Checklist](#6-verification-checklist)

---

## 1. What v5 Adds

| Service | Port | Purpose |
|---------|------|---------|
| Linkwarden | 3005 | Bookmark manager with local page archiving |
| Linkwarden PostgreSQL | — | Dedicated database for Linkwarden (internal) |
| Backrest | 9898 | Web UI for Restic backups; backs up stack data to NAS |

All v4 services carry forward unchanged.

> **Note:** CrowdSec, Loki, and Promtail are not in the `tools` stack.
> CrowdSec belongs in `infrastructure-networking` (v3). Loki and Promtail
> belong in `dashboards-automation` (v3). See the respective stack guides.

---

## 2. Update the Environment File

Add the following to `/opt/docker/stacks/tools/.env`:

```text
LINKWARDEN_DB_USER=
LINKWARDEN_DB_PASS=
LINKWARDEN_SECRET=
```

Generate `LINKWARDEN_SECRET`:

```bash
openssl rand -hex 32
```

---

## 3. Deploy v5

```bash
cd /opt/docker/stacks/tools
docker compose down
cp /path/to/repo/docker/tools/compose.v5.yaml compose.yaml
docker compose up -d
```

Verify all services are running:

```bash
docker compose ps
```

---

## 4. Configure Nginx Proxy Manager

| Service | Domain | Forward Host | Port | Websockets |
|---------|--------|-------------|------|-----------|
| Linkwarden | `links.home.bremmer.zone` | `linkwarden` | 3000 | On |
| Backrest | `backrest.home.bremmer.zone` | `backrest` | 9898 | Off |

---

## 5. First-Time Service Setup

### Linkwarden

Navigate to `http://192.168.11.10:3005`. On first start, Linkwarden
presents a registration form. The first user registered becomes the
admin. After creating your account, disable further signups in
**Settings** if you want a single-user setup.

To save a bookmark, paste a URL into the add link dialog. Linkwarden
fetches the page, stores a local archive, and extracts metadata.

Browser extensions for Chrome and Firefox are available in the
respective stores. Connect them using your server URL and credentials.

### Backrest

Navigate to `http://192.168.11.10:9898`. Create an admin account on
first start.

**Configure a repository** (where backups are stored):

1. Go to **Repos > Add Repo**
2. Set the URI to `/backups` (the NAS mount)
3. Set a strong repository password -- this encrypts the backup data.
   Store it securely. Without it, backups cannot be restored.
4. Click **Initialize**

**Configure a plan** (what to back up):

1. Go to **Plans > Add Plan**
2. Select your repository
3. Set the path to `/opt/docker/stacks` to back up all stack data
4. Set a schedule (e.g., daily at 2:00 AM via cron: `0 2 * * *`)
5. Set a retention policy (e.g., keep 7 daily, 4 weekly)

Run an initial backup manually from the Plans page to verify the
configuration before relying on the schedule.

> **NAS prerequisite:** The `/mnt/synology/backups` directory must
> exist on the NAS before deploying v5. Create it on the Synology
> before running `docker compose up -d`.

---

## 6. Verification Checklist

- [ ] `/mnt/synology/backups` exists on NAS before deploy
- [ ] `docker compose ps` shows all containers as `Up`
- [ ] Linkwarden accessible, account created
- [ ] Backrest accessible, repository initialized and first backup completed
- [ ] NPM proxy hosts created for Linkwarden and Backrest

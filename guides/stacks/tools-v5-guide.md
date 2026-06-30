# Tools Stack v5 Guide

This guide deploys the v5 migration of the `tools` stack, adding
Linkwarden and Backrest to the existing v4 deployment.

> **Prerequisite:** The `tools` stack must be running on `compose.v4.yaml`
> before migrating to v5.

---

## Contents

1. [What v5 Adds](#1-what-v5-adds)
2. [Mount the NAS Backup Share](#2-mount-the-nas-backup-share)
3. [Update the Environment File](#3-update-the-environment-file)
4. [Deploy v5](#4-deploy-v5)
5. [Configure Nginx Proxy Manager](#5-configure-nginx-proxy-manager)
6. [First-Time Service Setup](#6-first-time-service-setup)
7. [Verification Checklist](#7-verification-checklist)

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

## 2. Mount the NAS Backup Share

Backrest writes backups to the host path `/mnt/synology/backups`, which
`compose.v5.yaml` mounts into the container as `/backups`. **That host
path must be the actual NAS share, mounted over NFS** -- the same way
the Immich and Jellyfin media shares were mounted in
`../getting-started/homelab-v1-guide.md` section 2.2. If you skip this
step, Docker silently creates an empty local folder at that path on the
mini PC's own disk, and Backrest will happily back up to it with no
error -- your backups simply will not be on the NAS.

### 2.1 Create the Share on the Synology

In DSM:

1. **File Station** -- create a `backups` shared folder (or a
   subfolder of an existing share)
2. **Control Panel > Shared Folder > Edit > NFS Permissions** -- add a
   rule allowing your mini PC's IP, or the whole VLAN 11 subnet
   (`192.168.11.0/24`)
3. Note the NFS path DSM shows for the share, e.g. `/volume1/backups`

### 2.2 Mount It on the Host

```bash
sudo nano /etc/fstab
```

Add a line at the bottom, replacing `<nas-ip>` and the share path with
your actual values:

```
<nas-ip>:/volume1/backups   /mnt/synology/backups   nfs   defaults   0 0
```

Save and close (Ctrl+X, Y, Enter). Create the mount point and mount it:

```bash
sudo mkdir -p /mnt/synology/backups
sudo mount -a
```

Confirm it actually mounted:

```bash
df -h | grep synology
```

You should see a line for `backups`, alongside any existing Immich or
media mounts. **Do not proceed to Section 4 until this confirms** --
deploying Backrest before this mount exists is the most common way
backups end up on local disk instead of the NAS.

A complete reference copy of `/etc/fstab`'s NFS lines as of this
version is at [`config/v5/fstab`](../../config/v5/fstab).

---

## 3. Update the Environment File

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

## 4. Deploy v5

```bash
cd /opt/docker/stacks/tools
docker compose down
cp /path/to/repo/stacks/tools/compose.v5.yaml compose.yaml
docker compose up -d
```

Verify all services are running:

```bash
docker compose ps
```

---

## 5. Configure Nginx Proxy Manager

| Service | Domain | Forward Host | Port | Websockets |
|---------|--------|-------------|------|-----------|
| Linkwarden | `links.home.bremmer.zone` | `linkwarden` | 3000 | On |
| Backrest | `backrest.home.bremmer.zone` | `backrest` | 9898 | Off |

---

## 6. First-Time Service Setup

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

> **If `/backups` looks empty or the repo won't initialize:** the NAS
> mount from Section 2 likely isn't in place. Run `df -h | grep
> synology` on the host before troubleshooting Backrest itself.

---

## 7. Verification Checklist

- [ ] NAS share created and `df -h | grep synology` shows `backups` mounted on the host (Section 2)
- [ ] `docker compose ps` shows all containers as `Up`
- [ ] Linkwarden accessible, account created
- [ ] Backrest accessible, repository initialized and first backup completed
- [ ] First manual backup run from the Plans page completed without error
- [ ] NPM proxy hosts created for Linkwarden and Backrest

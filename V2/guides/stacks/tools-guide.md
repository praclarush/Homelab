# Tools Stack Guide

This guide covers the services in the `tools` stack beyond the base
WikiJS deployment (see
[getting-started/homelab-guide.md](../getting-started/homelab-guide.md)
for WikiJS itself and the stack's initial `.env` file): pgAdmin,
Stirling PDF, Mealie, n8n, IT Tools, Actual Budget, Paperless-ngx,
Grocy, Linkwarden, and Backrest.

> **Prerequisite:** The base `tools` stack (WikiJS) must already be
> running, per the getting-started guide.

---

## Contents

1. [What This Guide Adds](#1-what-this-guide-adds)
2. [Mount the Backup NAS Share](#2-mount-the-backup-nas-share)
3. [Update the Environment File](#3-update-the-environment-file)
4. [Deploy](#4-deploy)
5. [Configure Nginx Proxy Manager](#5-configure-nginx-proxy-manager)
6. [First-Time Service Setup](#6-first-time-service-setup)
7. [Verification Checklist](#7-verification-checklist)

---

## 1. What This Guide Adds

| Service | Port | Purpose |
|---------|------|---------|
| pgAdmin | 5050 | Web UI for managing all PostgreSQL instances |
| Stirling PDF | 8083 | Browser-based PDF tools (merge, split, OCR, convert) |
| Mealie | 9925 | Recipe manager with URL import and meal planning |
| n8n | 5678 | Workflow automation -- connects services and triggers actions |
| IT Tools | 8084 | Developer utilities (JWT decoder, UUID gen, hash tools, etc.) |
| Actual Budget | 5006 | Zero-based budgeting and expense tracking |
| Paperless-ngx | 8085 | Document management with OCR and full-text search |
| Paperless PostgreSQL | — | Dedicated database for Paperless (internal) |
| Paperless Redis | — | Paperless task queue (internal) |
| Grocy | 9283 | Household groceries, inventory, and chore management |
| Linkwarden | 3005 | Bookmark manager with local page archiving |
| Linkwarden PostgreSQL | — | Dedicated database for Linkwarden (internal) |
| Backrest | 9898 | Web UI for Restic backups; backs up stack data to NAS |

WikiJS and its PostgreSQL instance carry forward unchanged underneath
all of the above.

---

## 2. Mount the Backup NAS Share

Backrest writes backups to the host path `/mnt/synology/backups`, which
`compose.yaml` mounts into the container as `/backups`. **That host
path must be the actual NAS share, mounted over NFS** -- the same way
the Immich and Jellyfin media shares were mounted in
[getting-started/homelab-guide.md](../getting-started/homelab-guide.md#22-mount-the-base-nas-shares).
If you skip this step, Docker silently creates an empty local folder at
that path on the mini PC's own disk, and Backrest will happily back up
to it with no error -- your backups simply will not be on the NAS.

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

A complete reference copy of `/etc/fstab`'s NFS lines is at
[`config/fstab`](../../config/fstab).

---

## 3. Update the Environment File

Add the following to `/opt/docker/stacks/tools/.env`, alongside the
`DB_USER`/`DB_PASS`/`DB_NAME`/`VLAN11_IP` values from the getting-started
guide:

```text
PGADMIN_EMAIL=
PGADMIN_PASSWORD=
N8N_ENCRYPTION_KEY=
PAPERLESS_DB_USER=
PAPERLESS_DB_PASS=
PAPERLESS_SECRET_KEY=
LINKWARDEN_DB_USER=
LINKWARDEN_DB_PASS=
LINKWARDEN_SECRET=
```

Use any email address for `PGADMIN_EMAIL` -- it is the login username,
not a real email. Choose a strong `PGADMIN_PASSWORD`.

Generate `N8N_ENCRYPTION_KEY`, `PAPERLESS_SECRET_KEY`, and
`LINKWARDEN_SECRET`:

```bash
openssl rand -hex 32
```

`N8N_ENCRYPTION_KEY` encrypts stored credentials in n8n. Store it
securely -- if lost, all saved credentials in n8n will need to be
re-entered.

Grocy needs no `.env` entries of its own -- its `PUID`/`PGID`/`TZ`
values are set directly in `compose.yaml`.

---

## 4. Deploy

```bash
cd /opt/docker/stacks/tools
docker compose up -d
```

Paperless-ngx waits for its PostgreSQL and Redis health checks before
starting. On a cold start expect 30-60 seconds before the UI is
available.

Verify all services are running:

```bash
docker compose ps
```

Expected: `wikijs`, `wikijs_postgres`, `pgadmin`, `stirling_pdf`,
`mealie`, `n8n`, `it_tools`, `actual_budget`, `paperless_postgres`,
`paperless_redis`, `paperless_ngx`, `grocy`, `linkwarden_postgres`,
`linkwarden`, and `backrest` all show `Up`.

---

## 5. Configure Nginx Proxy Manager

Add these proxy hosts in the NPM admin panel
(`http://192.168.11.10:81`). All use the existing
`*.home.bremmer.zone` wildcard certificate. Use the internal container
ports, not the host-mapped ports.

| Service | Domain | Forward Host | Port | Websockets |
|---------|--------|-------------|------|-----------|
| pgAdmin | `pgadmin.home.bremmer.zone` | `pgadmin` | 80 | Off |
| Stirling PDF | `pdf.home.bremmer.zone` | `stirling_pdf` | 8080 | Off |
| Mealie | `mealie.home.bremmer.zone` | `mealie` | 9000 | Off |
| n8n | `n8n.home.bremmer.zone` | `n8n` | 5678 | On |
| IT Tools | `it-tools.home.bremmer.zone` | `it_tools` | 80 | Off |
| Actual Budget | `budget.home.bremmer.zone` | `actual_budget` | 5006 | Off |
| Paperless-ngx | `paperless.home.bremmer.zone` | `paperless_ngx` | 8000 | Off |
| Grocy | `grocy.home.bremmer.zone` | `grocy` | 80 | Off |
| Linkwarden | `links.home.bremmer.zone` | `linkwarden` | 3000 | On |
| Backrest | `backrest.home.bremmer.zone` | `backrest` | 9898 | Off |

> **n8n webhook dependency:** The `WEBHOOK_URL` in the compose file is
> set to `https://n8n.home.bremmer.zone`. Create the NPM proxy host
> before configuring any webhook-based workflows, or webhooks will
> fail to register correctly.

n8n requires websockets enabled for its editor to function correctly.

---

## 6. First-Time Service Setup

### pgAdmin

Navigate to `http://192.168.11.10:5050` and log in with the
`PGADMIN_EMAIL` and `PGADMIN_PASSWORD` from your `.env` file.

To add a PostgreSQL server connection, right-click **Servers** and
select **Register > Server**. The connection details for each instance:

| Instance | Host | Port | Database | Username |
|----------|------|------|----------|---------|
| WikiJS | `wikijs_postgres` | 5432 | `wikijs` | value of `DB_USER` |
| Authentik | `authentik_postgres` | 5432 | value of `PG_DB` | value of `PG_USER` |
| Immich | `immich_postgres` | 5432 | value of `DB_DATABASE_NAME` | value of `DB_USERNAME` |
| Paperless-ngx | `paperless_postgres` | 5432 | `paperless` | value of `PAPERLESS_DB_USER` |
| Linkwarden | `linkwarden_postgres` | 5432 | `linkwarden` | value of `LINKWARDEN_DB_USER` |

All PostgreSQL containers are on `proxy_net` and reachable from pgAdmin
by container name.

### Stirling PDF

No setup required. Navigate to `http://192.168.11.10:8083` and the
tool is ready to use. OCR support is available for PDF text extraction.

### Mealie

Navigate to `http://192.168.11.10:9925`. The default admin credentials
on first start are:

- Email: `changeme@example.com`
- Password: `MyPassword`

Change these immediately after first login in the admin panel under
**User Settings**.

`ALLOW_SIGNUP=false` is set in the compose file -- only the admin can
create additional accounts.

### n8n

Navigate to `http://192.168.11.10:5678`. On first start, n8n prompts
you to create an owner account. Complete the setup wizard before
building any workflows.

n8n stores workflows and credentials in `./n8n` on the host. This
directory is created automatically on first start.

### IT Tools

No setup required. Navigate to `http://192.168.11.10:8084`. All tools
are available immediately with no login.

### Actual Budget

Navigate to `http://192.168.11.10:5006`. On first start, Actual Budget
prompts you to create a new budget file. Budget files are stored in
`./actual-budget` and persist across restarts.

### Paperless-ngx

Create the admin account:

```bash
docker exec -it paperless_ngx python3 manage.py createsuperuser
```

Enter a username, email, and password when prompted. Then log in at
`http://192.168.11.10:8085`.

To ingest documents, drop files into `./paperless/consume` on the host.
Paperless monitors this directory and processes new files automatically.
Supported formats include PDF, JPG, PNG, TIFF, and Word documents.

### Grocy

Navigate to `http://192.168.11.10:9283`. Log in with the default
credentials (`admin` / `admin`) and change the password immediately
under **User Management**.

Grocy tracks groceries, household inventory, and chores. Start by
adding a few products under **Master Data > Products**, then use
**Purchase** and **Consume** to track stock as items come in and get
used. Config and the SQLite database persist in `./grocy/config` on
the host.

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
- [ ] pgAdmin accessible at `http://192.168.11.10:5050`
- [ ] Stirling PDF accessible at `http://192.168.11.10:8083`
- [ ] Mealie accessible at `http://192.168.11.10:9925`, default password changed
- [ ] n8n accessible at `http://192.168.11.10:5678`, owner account created
- [ ] IT Tools accessible at `http://192.168.11.10:8084`
- [ ] Actual Budget accessible at `http://192.168.11.10:5006`
- [ ] Paperless-ngx admin account created via `createsuperuser`; accessible at `http://192.168.11.10:8085`
- [ ] Grocy accessible at `http://192.168.11.10:9283`, default password changed
- [ ] Linkwarden accessible, account created
- [ ] Backrest accessible, repository initialized and first backup completed
- [ ] NPM proxy hosts created for every service in Section 5
- [ ] WikiJS still accessible at `https://wiki.home.bremmer.zone`

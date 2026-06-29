# Media-Gaming Stack v3 Guide

This guide deploys the v3 migration of the `media-gaming` stack, adding
Audiobookshelf and Kavita to the existing v2 deployment.

> **Prerequisite:** The `media-gaming` stack must be running on
> `compose.v2.yaml` before migrating to v3. NAS directories for
> audiobooks, podcasts, and books must exist before deploying.

---

## Contents

1. [What v3 Adds](#1-what-v3-adds)
2. [NAS Directory Prerequisites](#2-nas-directory-prerequisites)
3. [Deploy v3](#3-deploy-v3)
4. [Configure Nginx Proxy Manager](#4-configure-nginx-proxy-manager)
5. [First-Time Service Setup](#5-first-time-service-setup)
6. [Verification Checklist](#6-verification-checklist)

---

## 1. What v3 Adds

| Service | Port | Purpose |
|---------|------|---------|
| Audiobookshelf | 13378 | Audiobook and podcast server with iOS/Android apps |
| Kavita | 5000 | Ebook, manga, and comic reader |

Both services bind to `VLAN61_IP` (`192.168.61.10`) alongside Immich
and Jellyfin. They mount media directly from NAS.

All v2 services carry forward unchanged. No new `.env` variables are
required.

---

## 2. NAS Directory Prerequisites

Create the following directories on the Synology before deploying.
If they already exist with content, Audiobookshelf and Kavita will
index it on first scan.

```
/mnt/synology/audiobooks    # Audiobook files (mp3, m4b, m4a, etc.)
/mnt/synology/podcasts      # Podcast episode files
/mnt/synology/books         # Ebooks and comics (epub, cbz, pdf, etc.)
```

If your NAS paths differ, update the volume mounts in
`compose.v3.yaml` before deploying.

---

## 3. Deploy v3

```bash
cd /opt/docker/stacks/media-gaming
docker compose down
cp /path/to/repo/docker/media-gaming/compose.v3.yaml compose.yaml
docker compose up -d
```

Verify all services are running:

```bash
docker compose ps
```

Expected: all v2 containers plus `audiobookshelf` and `kavita` show `Up`.

---

## 4. Configure Nginx Proxy Manager

| Service | Domain | Forward Host | Port | Websockets |
|---------|--------|-------------|------|-----------|
| Audiobookshelf | `abs.home.bremmer.zone` | `audiobookshelf` | 13378 | On |
| Kavita | `kavita.home.bremmer.zone` | `kavita` | 5000 | On |

Both services are reached by container name over `proxy_net`.

---

## 5. First-Time Service Setup

### Audiobookshelf

Navigate to `http://192.168.61.10:13378`. Create an admin account on
first start. Then add your libraries:

1. Go to **Settings > Libraries > Add Library**
2. Add an **Audiobooks** library, set the folder to `/audiobooks`
3. Add a **Podcasts** library, set the folder to `/podcasts`
4. Click **Scan** on each library to index content

The iOS and Android apps connect using your server URL
(`https://abs.home.bremmer.zone`) and your account credentials.

### Kavita

Navigate to `http://192.168.61.10:5000`. The setup wizard runs on
first start -- create an admin account and set a server name.

Then add a library:

1. Go to **Server Settings > Libraries > Add Library**
2. Select a library type: **Books**, **Comics**, or **Manga**
3. Set the folder to `/books`
4. Kavita scans the directory and builds the library automatically

Kavita supports multiple library types pointing to different
subdirectories of `/books` if your collection is mixed.

---

## 6. Verification Checklist

- [ ] NAS directories exist at `/mnt/synology/audiobooks`, `/mnt/synology/podcasts`, `/mnt/synology/books`
- [ ] `docker compose ps` shows all containers as `Up`
- [ ] Audiobookshelf accessible at `http://192.168.61.10:13378`, libraries configured and scan completed
- [ ] Kavita accessible at `http://192.168.61.10:5000`, library scan completed
- [ ] NPM proxy hosts created for both services
- [ ] Existing v2 services (Jellyfin, Immich, AMP) still accessible

# Media-Gaming Stack v3 Guide

This guide deploys the v3 migration of the `media-gaming` stack, adding
Audiobookshelf and Kavita to the existing v2 deployment.

> **Prerequisite:** The `media-gaming` stack must be running on
> `compose.v2.yaml` before migrating to v3. The NAS shares for
> audiobooks, podcasts, and books must be created and mounted on the
> host before deploying.

---

## Contents

1. [What v3 Adds](#1-what-v3-adds)
2. [Mount the NAS Media Shares](#2-mount-the-nas-media-shares)
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

## 2. Mount the NAS Media Shares

`compose.v3.yaml` mounts three host paths directly into the
Audiobookshelf and Kavita containers:

```
/mnt/synology/audiobooks    # Audiobook files (mp3, m4b, m4a, etc.)
/mnt/synology/podcasts      # Podcast episode files
/mnt/synology/books         # Ebooks and comics (epub, cbz, pdf, etc.)
```

**Each of these must be the actual NAS share, mounted over NFS** -- the
same pattern used for Immich and Jellyfin in
`../getting-started/homelab-v1-guide.md` section 2.2. If you only
create local folders at these paths and skip the NFS mount, Docker
will start the containers without error, but Audiobookshelf and Kavita
will scan empty local directories instead of your NAS library.

### 2.1 Create the Shares on the Synology

In DSM, for each of `audiobooks`, `podcasts`, and `books`:

1. **File Station** -- create the shared folder (or use existing
   shares if your library is already organized that way)
2. **Control Panel > Shared Folder > Edit > NFS Permissions** -- add a
   rule allowing your mini PC's IP, or the VLAN 61 subnet
   (`192.168.61.0/24`)
3. Note the NFS path DSM shows for each share, e.g. `/volume1/audiobooks`

### 2.2 Mount Them on the Host

```bash
sudo nano /etc/fstab
```

Add one line per share at the bottom, replacing `<nas-ip>` and each
share path with your actual values:

```
<nas-ip>:/volume1/audiobooks   /mnt/synology/audiobooks   nfs   defaults   0 0
<nas-ip>:/volume1/podcasts     /mnt/synology/podcasts     nfs   defaults   0 0
<nas-ip>:/volume1/books        /mnt/synology/books        nfs   defaults   0 0
```

Save and close (Ctrl+X, Y, Enter). Create the mount points and mount
everything:

```bash
sudo mkdir -p /mnt/synology/audiobooks /mnt/synology/podcasts /mnt/synology/books
sudo mount -a
```

Confirm all three mounted:

```bash
df -h | grep synology
```

You should see a line for each of `audiobooks`, `podcasts`, and
`books`, alongside any existing Immich or media mounts. **Do not
proceed to Section 3 until all three confirm** -- this is the most
common reason a fresh Audiobookshelf or Kavita library scan comes back
empty.

A complete reference copy of `/etc/fstab`'s NFS lines as of this
version is at [`config/v3/fstab`](../../config/v3/fstab).

If your NAS paths differ from the ones above, update the volume mounts
in `compose.v3.yaml` to match before deploying.

---

## 3. Deploy v3

```bash
cd /opt/docker/stacks/media-gaming
docker compose down
cp /path/to/repo/stacks/media-gaming/compose.v3.yaml compose.yaml
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

> **If a library scan comes back empty:** the NAS mount from Section 2
> likely isn't in place. Run `df -h | grep synology` on the host before
> troubleshooting Audiobookshelf or Kavita themselves.

---

## 6. Verification Checklist

- [ ] NAS shares created and `df -h | grep synology` shows `audiobooks`, `podcasts`, and `books` all mounted on the host (Section 2)
- [ ] `docker compose ps` shows all containers as `Up`
- [ ] Audiobookshelf accessible at `http://192.168.61.10:13378`, libraries configured and scan completed
- [ ] Kavita accessible at `http://192.168.61.10:5000`, library scan completed
- [ ] NPM proxy hosts created for both services
- [ ] Existing v2 services (Jellyfin, Immich, AMP) still accessible

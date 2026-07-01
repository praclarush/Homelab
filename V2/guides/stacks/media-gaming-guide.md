# Media-Gaming Stack Guide

This guide covers the services in the `media-gaming` stack beyond the
base AMP and Immich deployment (see
[getting-started/homelab-guide.md](../getting-started/homelab-guide.md)
for AMP, Immich, and the stack's initial `.env` file): Jellyfin,
Audiobookshelf, and Kavita.

> **Prerequisite:** The base `media-gaming` stack (AMP, Immich) must
> already be running, per the getting-started guide. The NAS shares
> for audiobooks, podcasts, and books must be created and mounted on
> the host before deploying Audiobookshelf and Kavita.

---

## Contents

1. [What This Guide Adds](#1-what-this-guide-adds)
2. [Mount the NAS Media Shares](#2-mount-the-nas-media-shares)
3. [Deploy](#3-deploy)
4. [Configure Nginx Proxy Manager](#4-configure-nginx-proxy-manager)
5. [First-Time Service Setup](#5-first-time-service-setup)
6. [Verification Checklist](#6-verification-checklist)

---

## 1. What This Guide Adds

| Service | Port | Purpose |
|---------|------|---------|
| Jellyfin | 8096 | Media server |
| Audiobookshelf | 13378 | Audiobook and podcast server with iOS/Android apps |
| Kavita | 5000 | Ebook, manga, and comic reader |

All three bind to `VLAN61_IP` (`192.168.61.10`) alongside AMP and
Immich. They mount media directly from NAS. No new `.env` variables
are required beyond what the base stack already uses.

---

## 2. Mount the NAS Media Shares

`compose.yaml` mounts four host paths directly into the Jellyfin,
Audiobookshelf, and Kavita containers:

```
/mnt/synology/media         # Jellyfin's media library
/mnt/synology/audiobooks    # Audiobook files (mp3, m4b, m4a, etc.)
/mnt/synology/podcasts      # Podcast episode files
/mnt/synology/books         # Ebooks and comics (epub, cbz, pdf, etc.)
```

`/mnt/synology/media` should already be mounted from the
getting-started guide's base NAS setup. **Each of these must be the
actual NAS share, mounted over NFS.** If you only create local folders
at these paths and skip the NFS mount, Docker will start the containers
without error, but they will scan empty local directories instead of
your NAS library.

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
`books`, alongside the existing `immich` and `media` mounts. **Do not
proceed to Section 3 until all three confirm** -- this is the most
common reason a fresh Audiobookshelf or Kavita library scan comes back
empty.

A complete reference copy of `/etc/fstab`'s NFS lines is at
[`config/fstab`](../../config/fstab).

If your NAS paths differ from the ones above, update the volume mounts
in `compose.yaml` to match before deploying.

---

## 3. Deploy

```bash
cd /opt/docker/stacks/media-gaming
docker compose up -d
```

Verify all services are running:

```bash
docker compose ps
```

Expected: `amp`, `immich_server`, `immich_machine_learning`,
`immich_postgres`, `immich_redis`, `jellyfin`, `audiobookshelf`, and
`kavita` all show `Up`.

---

## 4. Configure Nginx Proxy Manager

| Service | Domain | Forward Host | Port | Websockets |
|---------|--------|-------------|------|-----------|
| Jellyfin | `jellyfin.home.bremmer.zone` | `jellyfin` | 8096 | On |
| Audiobookshelf | `abs.home.bremmer.zone` | `audiobookshelf` | 13378 | On |
| Kavita | `kavita.home.bremmer.zone` | `kavita` | 5000 | On |

All three are reached by container name over `proxy_net`.

---

## 5. First-Time Service Setup

### Jellyfin

1. Open `http://192.168.61.10:8096`
2. The first-launch wizard will ask for:
   - A preferred display language
   - A username and password for the Jellyfin admin account
   - A media library -- click **Add Media Library**:
     - **Content type:** Movies, TV Shows, or Music depending on your
       library
     - **Folders:** Click the `+` button and navigate to `/media`
       (this is the container path for `/mnt/synology/media`)
   - Complete the wizard and let the library scan run
3. Enable Intel Quick Sync hardware acceleration:
   - Go to **Admin Dashboard** (hamburger menu > Administration)
   - Click **Playback** in the left menu
   - Set **Hardware acceleration** to **Intel QuickSync (QSV)**
   - Check the hardware decoding boxes for the video formats you use
     (H.264 and H.265 are the most common)
   - Click **Save**
   - Restart the Jellyfin container to apply:
     ```bash
     docker restart jellyfin
     ```

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
> troubleshooting Jellyfin, Audiobookshelf, or Kavita themselves.

---

## 6. Verification Checklist

- [ ] NAS shares created and `df -h | grep synology` shows `media`, `audiobooks`, `podcasts`, and `books` all mounted on the host (Section 2)
- [ ] `docker compose ps` shows all containers as `Up`
- [ ] Jellyfin accessible at `http://192.168.61.10:8096`, media library scanned, hardware transcoding enabled
- [ ] Audiobookshelf accessible at `http://192.168.61.10:13378`, libraries configured and scan completed
- [ ] Kavita accessible at `http://192.168.61.10:5000`, library scan completed
- [ ] NPM proxy hosts created for all three services
- [ ] Existing AMP and Immich services still accessible

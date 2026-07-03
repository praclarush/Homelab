# Media-Gaming Stack Guide

This guide covers the services in the `media-gaming` stack beyond the
base AMP and Immich deployment (see
[getting-started/homelab-guide.md](../getting-started/homelab-guide.md)
for AMP, Immich, and the stack's initial `.env` file): Jellyfin,
Audiobookshelf, and Kavita.

> **Prerequisite:** The base `media-gaming` stack (AMP, Immich) must
> already be running, per the getting-started guide. The NAS shares
> for audiobooks, podcasts, and books should already be mounted from
> [section 2.2 of the getting-started
> guide](../getting-started/homelab-guide.md#22-mount-the-nas-shares),
> which covers every NAS share this repo needs in one place -- confirm
> before deploying Audiobookshelf and Kavita.

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

This should already be done -- every NAS share this repo needs,
including these four, is created and mounted in one place as part of
the base prerequisites in
[section 2.2 of the getting-started
guide](../getting-started/homelab-guide.md#22-mount-the-nas-shares),
before `media-gaming` first deploys. Confirm before proceeding:

```bash
df -h | grep synology
```

You should see a line for each of `media`, `audiobooks`, `podcasts`,
and `books`, alongside `immich` and `backups`. **Do not proceed to
Section 3 until all four confirm** -- this is the most common reason a
fresh Audiobookshelf or Kavita library scan comes back empty. **Each
must be the actual NAS share, mounted over NFS** -- if you only create
local folders at these paths and skip the NFS mount, Docker will start
the containers without error, but they will scan empty local
directories instead of your NAS library.

If any are missing, set them up now following
[section 2.2 of the getting-started guide](../getting-started/homelab-guide.md#22-mount-the-nas-shares)
rather than mounting them only for this stack -- `auth` and `tools`
depend on the `backups` share from that same section. A complete
reference copy of `/etc/fstab`'s NFS lines is at
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

- [ ] `df -h | grep synology` shows `media`, `audiobooks`, `podcasts`, and `books` all mounted on the host (created in getting-started guide section 2.2, confirmed in Section 2 here)
- [ ] `docker compose ps` shows all containers as `Up`
- [ ] Jellyfin accessible at `http://192.168.61.10:8096`, media library scanned, hardware transcoding enabled
- [ ] Audiobookshelf accessible at `http://192.168.61.10:13378`, libraries configured and scan completed
- [ ] Kavita accessible at `http://192.168.61.10:5000`, library scan completed
- [ ] NPM proxy hosts created for all three services
- [ ] Existing AMP and Immich services still accessible

# Dispatcharr IPTV Connection Manager

**Status: staged, not yet verified end-to-end.** No hardware dependency,
no new secrets -- config-only change. Originally sourced from
[jellywatch.app's Dispatcharr writeup](https://jellywatch.app/blog/dispatcharr-jellyfin-emby-iptv-connection-manager-2026)
for the service itself, and
[iptv-org/iptv](https://github.com/iptv-org/iptv) for a free test playlist
source. The volume layout and port below were wrong as inferred from that
article (container crash-looped on deploy) and have been corrected against
Dispatcharr's own
[docker-compose.aio.yml](https://github.com/Dispatcharr/Dispatcharr/blob/main/docker/docker-compose.aio.yml)
and [docs](https://dispatcharr.github.io/Dispatcharr-Docs/getting-started/).
The M3U/EPG output paths are also corrected below -- they're UI-generated
per-instance, not fixed paths.

## What This Is

Dispatcharr is a self-hosted stream proxy/connection manager that sits
between one or more IPTV sources and a media server, handling per-provider
connection limits, failover, and queueing, and re-exporting a merged
M3U playlist + XMLTV guide that Jellyfin consumes as a single Live TV
tuner:

```
IPTV provider(s) / iptv-org test playlist  -->  Dispatcharr (:9191)  -->
  Jellyfin Live TV (M3U Tuner + XMLTV guide)
```

Dispatcharr exposes its merged output as URLs generated per-instance
through its own UI, not fixed paths: on the **Channels** page, an **M3U**
button and an **EPG** button each copy a ready-to-paste URL. Grab those
from the running instance rather than assuming a path.

Jellyfin connects to those two output URLs directly -- this is Jellyfin's
Live TV **M3U Tuner** source type, not HDHomeRun emulation.

### Free test source

Before wiring up a paid IPTV subscription, validate the whole pipeline
(Dispatcharr connectivity, channel mapping, Jellyfin guide data) against
[iptv-org/iptv](https://github.com/iptv-org/iptv), a community-maintained
list of publicly available, free-to-air stream links -- no account or
credentials needed. A few of its hosted playlist URLs:

- All channels: `https://iptv-org.github.io/iptv/index.m3u`
- US only: `https://iptv-org.github.io/iptv/countries/us.m3u`
- Sports category: `https://iptv-org.github.io/iptv/categories/sports.m3u`

These are unofficial, user-submitted links to publicly available streams,
not licensed programming -- expect uneven reliability and don't treat this
as a permanent substitute for a real subscription if that's the eventual
plan. It's here to prove the pipeline works before paying for or entering
credentials for anything.

Most of these entries won't come with their own guide data. If you need
EPG for channels that lack it, [iptv-org/epg](https://github.com/iptv-org/epg)
generates XMLTV guides via a self-hosted grabber:

```bash
docker pull ghcr.io/iptv-org/epg:master
docker run -p 3000:3000 -v /path/to/channels.xml:/epg/public/channels.xml \
  ghcr.io/iptv-org/epg:master
```

This produces `http://localhost:3000/guide.xml`, but it needs a
`channels.xml` curated to your actual lineup and a supported site per
`SITES.md` in that repo -- treat it as an optional follow-up, not required
to get the test playlist working end-to-end, and not included as a service
in this migration item.

### VLAN placement

Decided: `VLAN11_IP`, not `VLAN61_IP` like the rest of `media-gaming`.
Unlike Jellyfin/Immich/etc., Dispatcharr has no actual NAS/NFS traffic --
it only talks to IPTV sources over the internet and to Jellyfin over
`proxy_net` by container name, so it doesn't need same-subnet NAS access.
Keeps VLAN61 strictly to NAS-adjacent traffic. This requires adding
`VLAN11_IP` to `media-gaming`'s `.env` (new for this stack -- see
`.env.example`).

## What's In This Folder

| File | Purpose |
|------|---------|
| `compose/dispatcharr-service-addition.yaml` | New `dispatcharr` service to add to `media-gaming`'s `compose.yaml` |

No `env-additions.txt` -- this item needs no new `.env` variables (see the
comment in the compose file).

## Setup

1. Add the `dispatcharr` service block from
   `compose/dispatcharr-service-addition.yaml` into
   `Docker/stacks/media-gaming/compose.yaml`.
2. `docker compose up -d` in `media-gaming`.
3. Open `http://<VLAN11_IP>:9191` and complete whatever first-run/admin
   setup Dispatcharr presents.
4. In Dispatcharr, add an IPTV provider pointing at one of the iptv-org
   test playlist URLs above (or your real provider's M3U/credentials, if
   you're confident enough to skip straight to it) and set its max
   connections.
5. Add an NPM proxy host for `dispatcharr.home.example.com` -> the
   dashboard, matching every other web-UI service in this repo (NPM's
   config lives in its own database, not a repo file, so this is a manual
   step, not a file change).
6. On Dispatcharr's **Channels** page, click the **M3U** button and copy
   the generated URL.
7. In Jellyfin: **Admin Dashboard > Live TV > Tuner Devices > Add** ->
   **M3U Tuner** -> paste that URL, swapping the host for `dispatcharr`
   (container-name resolution works since both are on `proxy_net`).
8. Back on Dispatcharr's **Channels** page, click the **EPG** button and
   copy that URL.
9. In Jellyfin: **Admin Dashboard > Live TV > Guide Data Providers > Add**
   -> **XMLTV** -> paste that URL (same `dispatcharr` host swap).
10. Map channels in Jellyfin's Live TV setup.

## Verify

- Dispatcharr dashboard loads at `http://<VLAN11_IP>:9191` and shows the
  test provider's channels populated.
- The M3U URL copied from the Channels page returns a non-empty playlist
  (`curl -s <url>`).
- Jellyfin's Live TV guide shows channels and program data.
- A channel actually plays back in Jellyfin without buffering/failing
  immediately.

## Promotion

Once verified:
- Merge the `dispatcharr` service into
  `Docker/stacks/media-gaming/compose.yaml`.
- Update this repo's root `CLAUDE.md` architecture table (`media-gaming`
  row) to list Dispatcharr alongside its port.
- Add a section to `stacks/media-gaming-guide.md` in the `Homelab-wiki`
  repo covering Dispatcharr setup, provider configuration, and the
  Jellyfin Live TV wiring above.
- If you moved past the iptv-org test source to a real subscription,
  note that provider's connection limits and any credentials handling in
  the wiki guide rather than this migration folder.
- Remove `Migrations/V2.3/dispatcharr-iptv/` and its row in
  `Migrations/V2.3/README.md`.

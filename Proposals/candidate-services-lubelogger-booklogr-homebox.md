# Candidate Services Review: LubeLogger, BookLogr, Homebox

**Date**: 2026-07-28
**Status**: Proposed -- awaiting review. No changes to any live stack; the
three items are staged under `Migrations/V2.4/` on branch
`task/candidate-services-v2.4` (staged, not deployed).

Three self-hosted services were researched as homelab replacements for
Android apps currently in use: **Fillup** (fuel/mileage tracking),
**Bookshelf** (physical book catalog + wishlist), and **Whiskey**
(spirits collection). Summary verdict up front, details per service below.

| Android app | Service | Verdict | Effort | Stack | Reason |
|---|---|---|---|---|---|
| Fillup | LubeLogger | **Recommend** | Low | `tools` | Purpose-built vehicle fuel + maintenance tracker. Single container, embedded DB, no new secrets. Direct one-for-one replacement plus maintenance reminders Fillup lacks |
| Bookshelf | BookLogr | **Recommend** | Low-Medium | `tools` | Tracks *physical* books (own / wishlist) via ISBN + OpenLibrary. Distinct job from the digital readers already running (Kavita, Audiobookshelf). Two-container topology is the only wrinkle |
| Whiskey | Homebox | **Recommend (generic)** | Low deploy / Medium setup | `tools` | No mature dedicated self-hosted whiskey/spirits app exists. Homebox is a general home-inventory manager configured with custom fields for the collection. Honest fit, not a perfect one |

All three are personal utility web apps with no NAS dependency, so they
land in `tools` on VLAN 11, unlike the NAS-adjacent media services which
sit in `media-gaming` on VLAN 61.

---

## 1. LubeLogger (replaces Fillup)

**What it is**: [LubeLogger](https://lubelogger.com/) is a web-based
vehicle maintenance and fuel-mileage tracker. Logs fuel fill-ups with
automatic MPG/cost charts, tracks service records, raises reminders for
oil changes / rotations / inspections by mileage or date, stores multiple
vehicles, and can attach digital copies of receipts and documents. It is
a genuine Fillup replacement rather than a workaround, and adds the
maintenance-reminder side Fillup does not cover.

**Docker**: Image `ghcr.io/hargata/lubelogger` (pin a version tag rather
than `latest`). Single container. Web UI listens on **8080** internally.
Backend is **LiteDB embedded by default** -- no Postgres sidecar required.
PostgreSQL is optional and only worth it for heavy multi-user use, which
does not apply here.

**Key volumes**: `/App/data` (vehicle data, LiteDB file) and `/App/keys`
(DataProtection keys -- must persist or sessions break on restart).
`/App/config`, `/App/log`, `/App/temp`, `/App/translations` are also
mountable if config/log persistence is wanted.

**Resource footprint**: Trivial. Small .NET container, embedded DB, no
Redis.

**Integration recommendation**:
- Stack: `tools`
- Bind: `${VLAN11_IP}:8086` and `${MESHNET_IP}:8086` -> container `8080`
  (8086 is unused by the live `tools` stack)
- Proxy: `lubelogger.home.bremmer.zone` via NPM on `proxy_net`
- Secrets: **none required**. Optional -- SMTP settings for reminder
  emails could point at the existing Postfix Relay
  (`infrastructure-networking`, port 25) so reminders arrive as real
  email. Optional, not required for core function.
- DB: LiteDB embedded (default). No new database service.

---

## 2. BookLogr (replaces Bookshelf)

**What it is**: [BookLogr](https://booklogr.app/) is a self-hosted
personal library tracker. Look up books by title or ISBN (powered by
OpenLibrary), file them into predefined lists -- **Reading**,
**Already Read**, **To Be Read** (the wishlist equivalent), and
**Did Not Finish** -- manually add books OpenLibrary doesn't have, and
track current-page progress.

This is a **physical**-book catalog + wishlist tool. It does *not* overlap
Kavita or Audiobookshelf, which serve digital ebooks/audiobooks. Bookshelf
on Android does the "what do I own / what do I want" job; BookLogr is the
direct analogue. (Bibliotheca is a viable alternative that leans harder
into reading-progress logging and monthly wrap-up images; BookLogr was
chosen as the cleaner own/wishlist catalog. BookLore/Calibre-Web were ruled
out -- those are ebook servers that duplicate Kavita.)

**Docker**: **Two containers** -- `mozzo/booklogr` (API) and
`mozzo/booklogr-web` (frontend). This is the only real operational wrinkle
of the three; the web frontend must be configured with the API's reachable
base URL. Backend is **SQLite by default**, with an optional
`docker-compose.postgres.yml` variant. SQLite is sufficient for
single-household use -- no Postgres sidecar needed.

**Resource footprint**: Low. Two small containers, embedded SQLite, no
Redis.

**Integration recommendation**:
- Stack: `tools`
- Bind: web `${VLAN11_IP}:3006` + `${MESHNET_IP}:3006` -> `80`; API
  `${VLAN11_IP}:8087` + `${MESHNET_IP}:8087` -> `5000` (see mesh caveat below)
- Proxy: **two** NPM hosts -- `booklogr.home.bremmer.zone` -> web, and
  `booklogr-api.home.bremmer.zone` -> API. `BL_API_ENDPOINT` **must** be
  the browser-reachable API hostname (the frontend is a client-side SPA
  that calls the API from the browser), not the internal container name.
  Verified against upstream's compose/docs.
- Secrets: `BOOKLOGR_AUTH_SECRET_KEY` (generated via `openssl rand -hex 32`)
  for multi-user mode; single-user mode needs none.
- Images: both containers pinned to `v1.11.1` and updated as a matched pair.
- DB: SQLite (default). No new database service.

---

## 3. Homebox (replaces Whiskey)

**What it is**: [Homebox](https://homebox.software/en/) is a general-purpose
self-hosted home-inventory manager -- items with custom fields, photos,
labels, locations, quantities, and optional barcode/QR. It is **not** a
whiskey app; it is the honest best-available answer, because every
dedicated spirits tracker (Distiller, Whiskeybase, Liquor Locker,
OnlyDrams) is cloud/mobile-only with no self-hosted option.

Used here, the spirits collection is modeled with custom fields for
distillery, type, ABV/proof, bottle size, fill level, price paid, and
tasting notes. That schema-setup is manual, which is why setup effort is
rated Medium even though deployment is trivial.

**Important maintainer note**: the original `hay-kot/homebox` project was
archived. The maintained continuation is **`ghcr.io/sysadminsmedia/homebox`**
-- use that, not the archived original. Verified current as of this doc's
date.

**Docker**: Image `ghcr.io/sysadminsmedia/homebox` (pin a version; a
`-rootless` tag exists if a non-root user is wanted). Single container. Web
UI on **7745**. Backend **SQLite by default** (`HBOX_DATABASE_DRIVER=sqlite3`),
Postgres optional. SQLite is fine here.

**Resource footprint**: Very small -- Go binary, ~50 MB RAM at idle, SQLite
on local disk.

**Integration recommendation**:
- Stack: `tools`
- Bind: `${VLAN11_IP}:7745` and `${MESHNET_IP}:7745` -> container `7745`
- Proxy: `homebox.home.bremmer.zone` via NPM on `proxy_net`
- Secrets: none required for the SQLite default. First-run creates the
  admin user in-app.
- DB: SQLite (default). No new database service.

**Alternative considered**: a no-code database (NocoDB / Baserow / Teable)
would give a fully bespoke spirits schema with grid/gallery views, at the
cost of more setup and a Postgres dependency. Homebox is the lower-effort
turnkey pick; note the alternative exists if the inventory model proves too
constraining. Grocy (already deployed) was ruled out -- it is oriented to
consumables/stock rotation, not a curated collection.

---

## Common Integration Notes

- **Stack**: all three join the existing `tools` stack, on `proxy_net`
  (`external: true`), with host ports dual-bound to `${VLAN11_IP}` (VLAN 11,
  NPM-proxied) and `${MESHNET_IP}` (direct mesh access), matching the
  mealie/grocy pattern already in the stack.
- **Mesh caveat (BookLogr only)**: because `BL_API_ENDPOINT` is a single
  URL, a mesh client opening the web UI at `${MESHNET_IP}:3006` still calls
  the API at its `${DOMAIN}` hostname, so mesh clients must resolve
  `*.${DOMAIN}` via Pi-hole. LubeLogger and Homebox have no such dependency.
- **DNS/proxy**: each gets an NPM proxy host under `*.home.bremmer.zone`;
  the existing Pi-hole dnsmasq wildcard already resolves new subdomains to
  `192.168.11.10`, so no per-service DNS record is needed.
- **Databases**: none of the three require a Postgres sidecar in the
  recommended topology -- LubeLogger uses embedded LiteDB, BookLogr and
  Homebox use embedded SQLite. This keeps the `tools` stack from gaining
  three more database containers.
- **Watchtower**: LubeLogger and Homebox run `:latest` with the
  `watchtower.enable=true` label, matching the tools stack's convention.
  BookLogr pins both containers to a matched version and omits the label --
  its API and web images are a released pair and must be bumped together,
  not auto-updated independently.

## Staging Plan (post-approval)

These are low-risk additive service adds to currently-deployed state,
staged as three items in **`Migrations/V2.4/`**, matching the current
`dispatcharr-iptv` item pattern:

- `Migrations/V2.4/lubelogger/` -- README + `compose/` service addition
- `Migrations/V2.4/booklogr/` -- README + `compose/` (two-service) addition + `env-additions.txt`
- `Migrations/V2.4/homebox/` -- README + `compose/` service addition

`Migrations/V2.4/README.md` carries the batch overview, the three-item
table, and a reference back to this proposal. Each item follows the
standard What This Is / What's In This Folder / Setup / Verify / Promotion
layout. Items are staged (not deployed) on branch
`task/candidate-services-v2.4`.

## Open Questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
| 1 | Confirm the app set: LubeLogger, BookLogr, Homebox -- or swap BookLogr->Bibliotheca / Homebox->NocoDB? | All staging | User | **Resolved** -- set confirmed; V2.4 items built for LubeLogger / BookLogr / Homebox |
| 2 | Host-port assignments (8086 LubeLogger, 3006 BookLogr web, 8087 BookLogr API, 7745 Homebox) -- confirm none collide with the live `tools` stack | Compose binds | User | **Resolved** -- checked against `Docker/stacks/tools/compose.yaml`; all four ports are unused |
| 3 | BookLogr two-container topology: expose the API on the host as well, or keep it internal to `proxy_net` and only proxy the web frontend? | BookLogr compose | User | **Resolved** -- API must be browser-reachable (client-side SPA), so it gets its own host bind + NPM host; internal-only is not viable |
| 4 | Whiskey use case: accept Homebox with a manual custom-field schema, or prefer a no-code DB (NocoDB/Baserow) for a bespoke collection model? | Homebox vs alternative | User | Open |
| 5 | LubeLogger reminder emails: wire optional SMTP through the existing Postfix Relay, or leave reminders in-app only? | LubeLogger config (optional) | User | Open |

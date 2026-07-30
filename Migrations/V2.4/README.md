# V2.4 — Minor Update to Production

Production is currently running the deployed state under `Docker/`.
`Migrations/V2.4/` holds a batch of minor, low-risk updates to that running
state: three new Docker Compose services added to the existing `tools`
stack, each with no hardware dependency. It's tracked as its own versioned
batch rather than standalone `Migrations/` items because it's meant to ship
as a discrete update to production, the same way `V3/` is a batch aimed at
its own future promotion.

All three services replace Android apps currently used for personal
tracking, and are personal utility web apps with no NAS/NFS traffic, so
they land in `tools` on VLAN 11 (not `media-gaming`/VLAN 61). Each is bound
on both `VLAN11_IP` (proxied internally by NPM) and `MESHNET_IP` (direct
access over the mesh network), matching the mealie/grocy pattern already in
this stack. Full research
and rationale, including alternatives considered, is in
[`Proposals/candidate-services-lubelogger-booklogr-homebox.md`](../../Proposals/candidate-services-lubelogger-booklogr-homebox.md).

Nothing under `V2.4/` is running yet. Each subfolder is one staged item,
self-contained with its own `README.md`.

## Promotion

Once a `V2.4/` item is verified working:

1. Merge its config into `Docker/stacks/tools/compose.yaml` (and its
   variable into that stack's `.env` / `.env.example` where applicable),
   following the existing file layout there.
2. Update this repo's root `CLAUDE.md` architecture table (`tools` row) to
   list the service alongside its port.
3. Add or update the relevant guide in the
   [`Homelab-wiki`](https://github.com/praclarush/Homelab-wiki) repo
   (`stacks/tools-guide.md`).
4. Remove the item's folder from `Migrations/V2.4/`.

## Staged Items

| Item | Replaces (Android) | Depends on | Summary |
|------|--------------------|-----------|---------|
| [lubelogger](lubelogger/README.md) | Fillup | Nothing (config-only; embedded LiteDB, no secrets) | Vehicle fuel/mileage + maintenance tracker, added to `tools` |
| [booklogr](booklogr/README.md) | Bookshelf | A generated `BOOKLOGR_AUTH_SECRET_KEY`; two NPM hosts (web + browser-reachable API); mesh access needs Pi-hole DNS (see item README bite #3) | Physical-book catalog + wishlist (ISBN/OpenLibrary). Two-container app (API + web) |
| [homebox](homebox/README.md) | Whiskey | Nothing (config-only; embedded SQLite, no secrets) | General home-inventory manager, configured as a spirits collection. Generic fit — no dedicated self-hosted whiskey app exists |

## Notes on versioning

`Migrations/V2.3/` (dispatcharr-iptv) was still open when this batch was
staged, and a `v2.4.0` tag already exists in the release history. This
folder was named `V2.4` per direct instruction; if the intended next batch
number is actually `V2.5`, rename the folder and update the internal
references before promotion.

# Homebox (spirits collection, via home inventory)

**Status: staged, not deployed.** No hardware dependency, no new secrets --
config-only change. Stands in for the **Whiskey** Android app.

**This is a generic fit, not a dedicated app.** No mature self-hosted
whiskey/spirits tracker exists -- every dedicated option (Distiller,
Whiskeybase, Liquor Locker, OnlyDrams) is cloud/mobile-only. Homebox is a
general home-inventory manager; the spirits collection is modeled with its
custom fields. If the inventory model proves too constraining, the
alternative is a no-code database (NocoDB/Baserow) -- see the proposal doc.

**Maintainer note**: the original `hay-kot/homebox` project is archived. Use
the maintained continuation `ghcr.io/sysadminsmedia/homebox`. Image, port,
and data path confirmed against the
[Homebox install docs](https://homebox.software/en/quick-start/install/).

## What This Is

Self-hosted home-inventory manager -- items with custom fields, photos,
labels, locations, quantities, and optional barcode/QR. Modeled here as a
spirits catalog: custom fields for distillery, type, ABV/proof, bottle
size, fill level, price paid, and tasting notes. That field setup is manual
and in-app after first run.

**Backend**: SQLite embedded (`HBOX_DATABASE_DRIVER` defaults to `sqlite3`),
stored in `/data`. No Postgres/Redis sidecar. Web UI on 7745.

**Resource footprint**: Very small -- Go binary, ~50 MB RAM at idle.

## What's In This Folder

| File | Purpose |
|------|---------|
| `compose/homebox-service-addition.yaml` | New `homebox` service to add to `tools`' `compose.yaml` |

No `env-additions.txt` -- no new `.env` variables. The one setting
(`HBOX_OPTIONS_ALLOW_REGISTRATION`) is inline in the compose file.

## Setup

1. Add the `homebox` service block from
   `compose/homebox-service-addition.yaml` into
   `Docker/stacks/tools/compose.yaml`.
2. `docker compose up -d homebox` in `tools`.
3. Open `http://<VLAN11_IP>:7745` (or `http://<MESHNET_IP>:7745` over the
   mesh network) and register your account.
4. **After your account exists**, set `HBOX_OPTIONS_ALLOW_REGISTRATION=false`
   in the compose file and `docker compose up -d homebox` again to lock down
   signups.
5. Add an NPM proxy host for `homebox.home.example.com` -> `homebox:7745`
   (manual step -- NPM config isn't a repo file).
6. Create a location (e.g. "Bar") and a label set, then add custom fields
   to items for distillery / ABV / proof / bottle size / fill level / price.

## Verify

- Dashboard loads at `http://<VLAN11_IP>:7745` and account registration
  completes.
- Also reachable over the mesh at `http://<MESHNET_IP>:7745`, not just the
  internal proxy.
- Add one test bottle with a photo and the custom fields above; confirm it
  saves and is searchable.
- Confirm registration is closed once `ALLOW_REGISTRATION=false` is applied
  (the sign-up option disappears).

## Promotion

Once verified:
- Merge the `homebox` service into `Docker/stacks/tools/compose.yaml`.
- Update this repo's root `CLAUDE.md` architecture table (`tools` row) to
  list Homebox and port 7745.
- Add a section to `stacks/tools-guide.md` in the `Homelab-wiki` repo,
  including the spirits custom-field schema so it's reproducible.
- Remove `Migrations/V2.4/homebox/` and its row in
  `Migrations/V2.4/README.md`.

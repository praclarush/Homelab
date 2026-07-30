# LubeLogger (vehicle fuel + maintenance tracker)

**Status: staged, not deployed.** No hardware dependency, no new secrets --
config-only change. Replaces the **Fillup** Android app.

Image, port, and volume paths confirmed against LubeLogger's own
[docker-compose.yml](https://github.com/hargata/lubelog/blob/main/docker-compose.yml)
and [getting-started docs](https://docs.lubelogger.com/Installation/Getting%20Started/).

## What This Is

A web-based vehicle maintenance and fuel-mileage tracker. Logs fuel
fill-ups with automatic MPG/cost charts, tracks service records, raises
reminders for oil changes / rotations / inspections by mileage or date,
handles multiple vehicles, and attaches receipts/documents. Direct Fillup
replacement, plus maintenance reminders Fillup doesn't have.

**Backend**: LiteDB embedded, stored in `/App/data` -- no Postgres/Redis
sidecar. DataProtection keys persist at `/root/.aspnet/DataProtection-Keys`;
this **must** be mounted or every restart invalidates existing login
sessions.

**Resource footprint**: Trivial. Small .NET container, embedded DB.

## What's In This Folder

| File | Purpose |
|------|---------|
| `compose/lubelogger-service-addition.yaml` | New `lubelogger` service to add to `tools`' `compose.yaml` |

No `env-additions.txt` -- this item needs no new `.env` variables. Reminder
emails are optional and, if wanted, are configured in-app against the
existing Postfix Relay (`infrastructure-networking`, port 25).

## Setup

1. Add the `lubelogger` service block from
   `compose/lubelogger-service-addition.yaml` into
   `Docker/stacks/tools/compose.yaml`.
2. `docker compose up -d lubelogger` in `tools`.
3. Open `http://<VLAN11_IP>:8086` (or `http://<MESHNET_IP>:8086` over the
   mesh network) and complete first-run admin setup.
4. Add an NPM proxy host for `lubelogger.home.example.com` -> `lubelogger:8080`
   (container-name resolution works since both are on `proxy_net`). NPM's
   config lives in its own database, not a repo file, so this is a manual
   step.

## Verify

- Dashboard loads at `http://<VLAN11_IP>:8086` and first-run setup
  completes.
- Also reachable over the mesh at `http://<MESHNET_IP>:8086`, not just the
  internal proxy.
- Add a vehicle and one fuel record; confirm the MPG/cost chart renders.
- Restart the container (`docker compose restart lubelogger`) and confirm
  you stay logged in -- proves the DataProtection-Keys volume is persisting.

## Promotion

Once verified:
- Merge the `lubelogger` service into `Docker/stacks/tools/compose.yaml`.
- Update this repo's root `CLAUDE.md` architecture table (`tools` row) to
  list LubeLogger and port 8086.
- Add a section to `stacks/tools-guide.md` in the `Homelab-wiki` repo.
- Remove `Migrations/V2.4/lubelogger/` and its row in
  `Migrations/V2.4/README.md`.

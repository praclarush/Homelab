# V3 — Staged Changes

`Docker/V3/` holds changes that are designed and ready to apply but not yet
deployed to the live homelab, because they depend on something not yet in
place -- usually new physical hardware. It sits alongside `Docker/V1/`
(historical, do not add to) and `Docker/V2/` (the live, deployed state).

Nothing under `V3/` is running. Each subfolder is one staged item and is
self-contained: its own `README.md` with setup/deployment instructions, plus
whatever config files it introduces.

## Promotion

Once a `V3/` item's hardware or external dependency is in place and the
change has been verified working:

1. Merge its config into the relevant `Docker/V2/stacks/` service or host
   config, following the existing file layout there.
2. Add or update the relevant guide under `Docker/V2/guides/`.
3. Remove the item's folder from `Docker/V3/`.

## Staged Items

| Item | Depends on | Summary |
|------|-----------|---------|
| [rack-temperature-monitoring](rack-temperature-monitoring/README.md) | ESP32 dev board (unpurchased) | TempPro TP350 rack temperature/humidity sensor, read via an ESPHome Bluetooth proxy, alerting through Home Assistant and ntfy |

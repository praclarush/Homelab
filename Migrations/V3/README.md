# V3 — Staged Changes

`Migrations/V3/` holds changes that are designed and ready to apply
but not yet deployed to the live homelab, because they depend on something
not yet in place -- new physical hardware, an unverified assumption, or a
credential/account that needs to be created first. It sits alongside
`Docker/stacks/`, `Docker/config/`, and `Guides/` (the live, deployed
state).

Nothing under `V3/` is running. Each subfolder is one staged item and is
self-contained: its own `README.md` with setup/deployment instructions, plus
whatever config files it introduces.

See [`HARDWARE-TO-BUY.md`](HARDWARE-TO-BUY.md) for a consolidated shopping
list across all staged items.

## Promotion

Once a `V3/` item's hardware or external dependency is in place and the
change has been verified working:

1. Merge its config into the relevant `Docker/stacks/` service or host
   config, following the existing file layout there.
2. Add or update the relevant guide under `Guides/`.
3. Remove the item's folder from `Migrations/V3/`.

## Staged Items

| Item | Depends on | Alerting via | Summary |
|------|-----------|--------------|---------|
| [rack-temperature-monitoring](rack-temperature-monitoring/README.md) | ESP32 dev board (unpurchased) | Home Assistant + ntfy | TempPro TP350 rack temperature/humidity sensor, read via an ESPHome Bluetooth proxy |
| [pc-temperature-alerting](pc-temperature-alerting/README.md) | Confirming `node_hwmon_temp_celsius` has data | Home Assistant + ntfy | Mini PC temperature via the existing node-exporter/Prometheus |
| [unifi-temperature-monitoring](unifi-temperature-monitoring/README.md) | Local read-only UniFi account | **Grafana** + ntfy (not Home Assistant -- see item's README) | UniFi switch/UDM Pro temperature via `unpoller` into Prometheus |
| [zigbee-smart-home](zigbee-smart-home/README.md) | Zigbee coordinator (unpurchased, SLZB-06 recommended) | n/a (device bridge, not an alert source) | Zigbee2MQTT + Mosquitto bridging a network-attached coordinator into Home Assistant via MQTT discovery |

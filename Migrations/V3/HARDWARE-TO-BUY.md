# Hardware to Buy — V3 Staged Items

Consolidated shopping list across all `Migrations/V3/` items. See each item's
own `README.md` for setup instructions once hardware is in hand.
`pc-temperature-alerting` and `unifi-temperature-monitoring` need no
hardware purchases (existing infrastructure + a UniFi account) and are
not listed below.

## rack-temperature-monitoring

Required (choose one power option):

| Item | Approx. Cost | Notes |
|------|-------------|-------|
| ESP32 dev board ("ESP32-WROOM-32 DevKitC", any brand) | $6-10 | No soldering. WiFi only. |
| USB data cable (Micro-USB or USB-C, matching the board) | — | Must carry data, not charge-only. |
| USB power source at the rack (wall adapter or powered hub port) | — | Runs continuously; not battery powered. |

Already owned: TempPro TP350-US (placed in/on the rack).

**PoE alternative** — skip the wall-plug/USB-power line above if a PoE
switch port is available at the rack instead:

| Item | Approx. Cost | Notes |
|------|-------------|-------|
| Olimex ESP32-POE-ISO (preferred) | ~$27 | Galvanically isolated; safer near other rack gear. |
| — or — LILYGO T-ETH-POE | ~$20 | Cheaper alternative, not isolated. |
| PoE injector | ~$12 | Only needed if the switch port isn't already PoE-capable (802.3af). |

## zigbee-smart-home

| Item | Approx. Cost | Notes |
|------|-------------|-------|
| SMLIGHT SLZB-06 (Zigbee coordinator, CC2652P radio) | ~$45 | Ethernet/PoE/USB/WiFi capable — Ethernet or PoE avoids USB passthrough on any container. |
| Ethernet drop + PoE switch port or injector | ~$12 (injector, if needed) | Wherever Zigbee coverage is needed; same PoE considerations as the rack sensor. |

## Total New Purchases

- Minimum (rack sensor, WiFi/USB power + SLZB-06): **~$51-55**
- With PoE for both (rack sensor + Zigbee coordinator, assuming one
  shared PoE injector isn't reusable across both locations): **~$79-96**

Reuse one PoE injector across both items if they'll sit at the same
physical location; otherwise budget one per location.

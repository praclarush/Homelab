# Rack Temperature Monitoring (TempPro TP350 + ESPHome BLE Proxy)

**Status: staged, not deployed.** Blocked on buying and provisioning an
ESP32 dev board.

## What This Is

A TempPro TP350 hygrometer/thermometer placed in the server rack broadcasts
temperature and humidity over Bluetooth Low Energy every ~10 seconds. It has
no WiFi and no API of its own -- an ESP32 running ESPHome's Bluetooth proxy
firmware sits near the rack, listens for those broadcasts, and forwards them
to Home Assistant over the LAN. Home Assistant's built-in `ThermoPro`
integration decodes the TP350 automatically once its advertisements are
visible through the proxy -- no local Bluetooth adapter on the mini PC is
required and no changes to the `homeassistant` container's networking are
needed.

An automation then watches the resulting temperature sensor and posts to
ntfy (already running in `infrastructure-networking`) when it crosses a
threshold.

```
TP350 (BLE broadcast) --> ESP32 / ESPHome bluetooth_proxy --> WiFi -->
  Home Assistant (ThermoPro integration decodes it) --> automation --> ntfy
```

## What's In This Folder

| File | Purpose |
|------|---------|
| `esphome/rack-ble-proxy.yaml` | ESPHome firmware config for the ESP32 proxy |
| `esphome/secrets.yaml.example` | Template for the WiFi/API/OTA secrets the config above references |
| `homeassistant/configuration-additions.yaml` | `rest_command` to merge into HA's `configuration.yaml` |
| `homeassistant/automations-additions.yaml` | Alert automation to append to HA's `automations.yaml` |

## Hardware Needed

- One generic ESP32 dev board (e.g. "ESP32-WROOM-32 DevKitC", any brand --
  roughly $6-10). No soldering required.
- A USB cable to match its port (Micro-USB or USB-C depending on the board)
  that carries data, not just power -- some bundled cables are charge-only.
- A USB power source at the rack for permanent placement (wall adapter or
  spare port on a powered hub). The board runs continuously; it is not
  battery powered.
- The TempPro TP350 itself, placed in or on the rack.

### Power Option: PoE Instead of a Wall Plug

The generic DevKitC above is WiFi-only -- no Ethernet, so it needs a wall
outlet or powered USB hub. If a wall outlet at the rack is inconvenient, or
a PoE switch port is already available there, swap in an Ethernet+PoE board
instead, e.g. **Olimex ESP32-POE-ISO** (~$27, galvanically isolated --
preferred over the non-isolated ESP32-POE when sitting near other rack
gear) or **LILYGO T-ETH-POE** (~$20). Same ESP32 chip, so BLE scanning and
`bluetooth_proxy` are unaffected; only the network transport changes.
Requires an 802.3af PoE switch port or a PoE injector (~$12) if the switch
doesn't inject power itself.

If using a PoE board, replace the `wifi:` and `captive_portal:` blocks in
`esphome/rack-ble-proxy.yaml` with:

```yaml
ethernet:
  type: LAN8720
  mdc_pin: GPIO23
  mdio_pin: GPIO18
  clk_mode: GPIO17_OUT
  phy_addr: 0
  power_pin: GPIO12
```

(Pin values above match the Olimex ESP32-POE/POE-ISO; confirm against the
specific board's pinout before flashing, since PoE boards vary here.) Also
drop `wifi_ssid`/`wifi_password`/`wifi_fallback_password` from
`secrets.yaml` since they're no longer referenced.

As a side benefit beyond cabling: the ESP32's WiFi and Bluetooth radios
share one antenna time-sliced, so a WiFi-connected proxy can occasionally
miss BLE advertisements during WiFi activity. Ethernet frees the radio for
BLE exclusively, which should make passive scanning more consistent.

## Setup

### 1. Prepare the ESPHome config

```bash
cd Migrations/V3/rack-temperature-monitoring/esphome
cp secrets.yaml.example secrets.yaml
```

Edit `secrets.yaml`:
- `wifi_ssid` / `wifi_password` -- the network the ESP32 will join. It needs
  to be reachable from wherever Home Assistant's container runs (VLAN 11).
- `api_encryption_key` -- generate with `openssl rand -base64 32`.
- `wifi_fallback_password` / `ota_password` -- any password 8+ characters.

`secrets.yaml` is for local use only -- keep it out of version control
(the `.example` file is what's tracked).

### 2. Install the ESPHome CLI

On the machine you'll use to flash the board (does not need to be the mini
PC):

```bash
pip install esphome
```

### 3. Flash the ESP32 over USB

Plug the ESP32 into that machine via USB, then from the `esphome/` folder:

```bash
esphome run rack-ble-proxy.yaml
```

Select the board's serial/COM port when prompted. This compiles the
firmware and flashes it over USB -- the only time a physical USB connection
is needed. Watch the log output to confirm it joins WiFi.

### 4. Add it to Home Assistant

Within about a minute of boot, Home Assistant should show a discovery
notification for a new ESPHome device (`rack-ble-proxy`), found via mDNS on
the local network. Go to **Settings > Devices & Services**, accept the
discovered device, and enter the same `api_encryption_key` from
`secrets.yaml` when prompted.

No separate "Bluetooth" integration setup is needed -- adding the ESPHome
device automatically registers it as a Bluetooth scanner source for Home
Assistant's Bluetooth integration.

### 5. Place the hardware

Position the ESP32 (powered, connected to WiFi) within Bluetooth range of
the TP350 in the rack -- a few feet is plenty; BLE doesn't need
line-of-sight at that distance. Make sure the ESP32's WiFi placement still
has a usable signal; rack chassis metal can attenuate it more than open air.

### 6. Confirm the TP350 is discovered

Once the proxy is in range and powered, Home Assistant should surface a
second discovery notification for a `ThermoPro` device within a few
advertisement cycles (~10s each). Accept it under **Settings > Devices &
Services**.

Find its actual entity ID: **Settings > Devices & Services > Devices** >
the new TP350 device > **Sensors** tab. Note the temperature sensor's
entity_id (something like `sensor.tp350_a1b2_temperature`).

### 7. Wire up HA config

On the host, merge the two staged files into HA's live (gitignored)
config:
- Add the `rest_command` block from `configuration-additions.yaml` into
  `configuration.yaml`.
- Append the automation from `automations-additions.yaml` into
  `automations.yaml`, replacing both
  `sensor.REPLACE_WITH_TP350_TEMPERATURE_ENTITY` placeholders with the
  entity_id found in step 6. Adjust the 85°F threshold if you want a
  different trip point for the rack.

Reload: **Developer Tools > YAML > Rest Commands** and **> Automations**
(or restart the `homeassistant` container).

### 8. Subscribe to the ntfy topic

The alert posts to the `rack-temp` topic on the existing ntfy instance
(`https://ntfy.home.bremmer.zone/rack-temp` or the ntfy app pointed at that
server/topic). Subscribe there to receive it. Change the topic name in
`configuration-additions.yaml` before merging if you'd rather use a
different one.

### 9. Verify

- **Developer Tools > States**: confirm the TP350 temperature/humidity
  sensors are updating roughly every 10 seconds.
- **Settings > Automations**: open "Server Rack - High Temperature Alert"
  and use **Run actions** to fire it manually, confirming the ntfy
  notification arrives.
- Optionally, breathe on the TP350 or otherwise raise its reading above the
  threshold and confirm the automation fires for real after the 5-minute
  sustained condition.

## Promotion

Once verified against real hardware:
- Move the merged `configuration.yaml`/`automations.yaml` changes stay on
  the host as-is (they're gitignored runtime state either way).
- Move `esphome/rack-ble-proxy.yaml` (without secrets) into a tracked
  location, e.g. `Docker/stacks/dashboards-automation/esphome/`, and add
  a short section to `stacks/dashboards-automation-guide.md` in the
  `Homelab-wiki` repo covering it.
- Remove `Migrations/V3/rack-temperature-monitoring/` and its row in
  `Migrations/V3/README.md`.

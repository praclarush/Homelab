# Zigbee Smart Home (SLZB-06 + Zigbee2MQTT + Mosquitto, into Home Assistant)

**Status: staged, not deployed.** Blocked on buying a Zigbee coordinator
(SLZB-06 recommended).

## What This Is

A network-attached Zigbee coordinator (SMLIGHT SLZB-06 or similar --
Ethernet/PoE/USB, CC2652P radio) feeds Zigbee2MQTT, which publishes every
paired device to an MQTT broker (Mosquitto). Home Assistant's built-in MQTT
integration auto-discovers those devices from Mosquitto and creates normal
HA entities for them -- no manual per-device YAML, and no second place
devices "live." Zigbee2MQTT's own web frontend is only used for
pairing/network management; day-to-day control and automation stays in
Home Assistant, same as everything else in this homelab.

The coordinator being network-attached (not USB) means neither
`zigbee2mqtt` nor `homeassistant` needs any device passthrough or
`network_mode: host` change -- it's a plain TCP connection like anything
else on `proxy_net`.

```
Zigbee devices --> SLZB-06 (Ethernet/PoE) --> Zigbee2MQTT --> Mosquitto -->
  Home Assistant (MQTT integration, auto-discovery) --> automations / ntfy
```

## What's In This Folder

| File | Purpose |
|------|---------|
| `compose/mosquitto-service-addition.yaml` | New `mosquitto` (MQTT broker) service for `dashboards-automation`'s `compose.yaml` |
| `compose/zigbee2mqtt-service-addition.yaml` | New `zigbee2mqtt` service for the same `compose.yaml` |
| `compose/env-additions.txt` | New `.env` / `.env.example` variables |
| `mosquitto/mosquitto.conf` | Mosquitto config: authenticated, no anonymous access |
| `zigbee2mqtt/configuration-template.yaml` | Zigbee2MQTT config: MQTT base topic, coordinator address, HA discovery enabled |

## Hardware Needed

- A network-attached Zigbee coordinator. Recommended:
  **SMLIGHT SLZB-06** (CC2652P radio, supports Ethernet, PoE 802.3af, USB,
  or WiFi -- Ethernet/PoE is the point here, to avoid tying it to the mini
  PC or a wall outlet). A USB-attached coordinator (e.g. Home Assistant
  Connect ZBT-2) would also work with Zigbee2MQTT, but would need a
  `devices:` passthrough on whichever container it's plugged into --
  not drafted here since the SLZB-06 avoids that entirely.
- Ethernet drop + PoE switch port or injector at wherever you want Zigbee
  coverage (same considerations as the rack sensor's ESP32).

## Setup

### 1. Set Up Mosquitto Authentication

Create the password file on the host before first start (Mosquitto
container image ships the `mosquitto_passwd` tool, run once via a
throwaway container):

```bash
mkdir -p /opt/docker/stacks/dashboards-automation/mosquitto/config
docker run --rm -it \
  -v /opt/docker/stacks/dashboards-automation/mosquitto/config:/mosquitto/config \
  eclipse-mosquitto \
  mosquitto_passwd -c /mosquitto/config/passwd zigbee2mqtt

docker run --rm -it \
  -v /opt/docker/stacks/dashboards-automation/mosquitto/config:/mosquitto/config \
  eclipse-mosquitto \
  mosquitto_passwd /mosquitto/config/passwd homeassistant
```

(Second command has no `-c` so it appends a second user instead of
overwriting the file.) Record both passwords -- the `zigbee2mqtt` one goes
in `.env`, the `homeassistant` one gets entered directly into HA's UI in
step 5.

Copy `mosquitto/mosquitto.conf` from this folder to
`/opt/docker/stacks/dashboards-automation/mosquitto/config/mosquitto.conf`.

The `eclipse-mosquitto` image runs as a non-root `mosquitto` user
(UID/GID `1883`) by default. If `./mosquitto/data` and `./mosquitto/log`
don't exist before the container's first start, Docker auto-creates them
as root-owned, and Mosquitto fails to write its persistence file and log
(`Error: Unable to open log file` / permission denied) and crash-loops.
Create and own them explicitly before step 4:

```bash
mkdir -p /opt/docker/stacks/dashboards-automation/mosquitto/data \
         /opt/docker/stacks/dashboards-automation/mosquitto/log
chown -R 1883:1883 /opt/docker/stacks/dashboards-automation/mosquitto/data \
                    /opt/docker/stacks/dashboards-automation/mosquitto/log
```

### 2. Merge Compose and Env Changes

- Add both service blocks from `compose/mosquitto-service-addition.yaml`
  and `compose/zigbee2mqtt-service-addition.yaml` into
  `dashboards-automation`'s `compose.yaml`.
- Add the variables from `compose/env-additions.txt` to `.env` (real
  `zigbee2mqtt` password from step 1) and `.env.example` (blank).

### 3. Configure Zigbee2MQTT

Copy `zigbee2mqtt/configuration-template.yaml` to
`/opt/docker/stacks/dashboards-automation/zigbee2mqtt/data/configuration.yaml`,
and set `serial.port` to the SLZB-06's actual address -- copy the exact
value from the SLZB-06's own web dashboard (its Z2M/ZHA menu generates
this for you, including the port, which defaults to 6638 but is
changeable in its firmware) rather than guessing it.

### 4. Deploy

```bash
cd /opt/docker/stacks/dashboards-automation
docker compose up -d mosquitto zigbee2mqtt
docker compose logs -f zigbee2mqtt
```

Confirm the log shows Zigbee2MQTT connecting to both the MQTT broker and
the SLZB-06 coordinator without errors. Its frontend is reachable at
`http://192.168.11.10:8086` for pairing devices (set `permit_join: true`
temporarily while pairing, then back to `false`).

### 5. Add Home Assistant's MQTT Integration

**Settings > Devices & Services > Add Integration > MQTT**
- Broker: `mosquitto`
- Port: `1883`
- Username / Password: the `homeassistant` credentials from step 1

Once connected, pair a Zigbee device in the Zigbee2MQTT frontend -- it
should appear automatically as a new device under the MQTT integration in
Home Assistant within a few seconds, with no HA-side YAML needed.

## Verify

- Zigbee2MQTT frontend shows the coordinator connected and lists paired
  devices.
- **Settings > Devices & Services > MQTT** in Home Assistant shows each
  paired device with live-updating entities.
- Trigger a test automation or manual notification using a newly
  discovered entity to confirm it behaves like any other HA entity
  (reusable with the same `rest_command`/ntfy pattern as the rack and PC
  temperature alerts).

## Promotion

Once verified:
- Merge both service blocks into
  `Docker/stacks/dashboards-automation/compose.yaml` and the env vars
  into that stack's real `.env.example`.
- `mosquitto.conf` and the Zigbee2MQTT `configuration.yaml` stay on the
  host as gitignored runtime state (matching how Home Assistant's config
  is handled) -- only the compose service definitions and this template
  are tracked.
- Add a short section to `stacks/dashboards-automation-guide.md` in the
  `Homelab-wiki` repo covering Mosquitto, Zigbee2MQTT, and the HA MQTT
  integration setup.
- Remove `Migrations/V3/zigbee-smart-home/` and its row in
  `Migrations/V3/README.md`.

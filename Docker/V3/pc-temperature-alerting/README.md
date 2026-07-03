# Mini PC Temperature Alerting (Home Assistant, via existing Prometheus)

**Status: staged, not deployed.** Blocked on confirming the metric this
depends on actually has data (see Verify First below) -- no hardware
purchase needed.

## What This Is

The mini PC's hardware temperature is likely already being collected: the
`node-exporter` service in `dashboards-automation` runs with
`network_mode: host` + `pid: host` + a `/:/host:ro,rslave` mount and
`--path.rootfs=/host`, which is the documented pattern for getting real
host sensor data out of a containerized node_exporter. Its `hwmon`
collector is enabled by default and, if the board exposes
coretemp/hwmon-compatible sensors to the kernel, is already publishing
`node_hwmon_temp_celsius` to Prometheus.

This item adds a Home Assistant REST sensor that queries that existing
metric from Prometheus, and an automation that posts to ntfy when it runs
hot -- no new containers, no changes to `node-exporter`, `prometheus`, or
`docker-compose.yaml`.

```
node-exporter (hwmon) --> Prometheus (already scraping) -->
  HA rest sensor --> automation --> ntfy
```

## Verify First

Before merging anything, confirm the metric has data:

```bash
curl -s "http://192.168.11.10:9090/api/v1/query?query=node_hwmon_temp_celsius" | jq
```

- **Returns one or more results:** proceed with setup below.
- **Returns an empty `result` array:** the board isn't exposing
  hwmon-compatible sensors to the kernel (missing driver, e.g. `it87`, or
  hardware that just doesn't support it). That's an OS-level problem
  (`sensors-detect` / `lm-sensors` troubleshooting on the host) separate
  from this item -- nothing to wire up in Home Assistant until that's
  resolved.

The automation below uses `max(node_hwmon_temp_celsius)` across all
reported sensors (CPU cores, chipset, etc.) rather than pinning to one
`chip`/`sensor` label pair, since exact hwmon labels vary by hardware. If
you want to alert on one specific sensor instead (e.g. just the CPU
package), inspect the labels from the query above and narrow the
PromQL query in `configuration-additions.yaml` accordingly.

## What's In This Folder

| File | Purpose |
|------|---------|
| `homeassistant/configuration-additions.yaml` | `rest` sensor (queries Prometheus) + `rest_command` (posts to ntfy) to merge into HA's `configuration.yaml` |
| `homeassistant/automations-additions.yaml` | Alert automation to append to HA's `automations.yaml` |

## Setup

1. Run the verification query above.
2. Merge `homeassistant/configuration-additions.yaml` into
   `configuration.yaml` on the host. If `rest:` or `rest_command:` keys
   already exist there (e.g. from the rack-temperature-monitoring item),
   add these entries under the existing keys rather than duplicating them.
3. Append `homeassistant/automations-additions.yaml` to `automations.yaml`.
4. Reload: **Developer Tools > YAML > REST** (or restart `homeassistant`),
   then **Developer Tools > YAML > Automations**.
5. Subscribe to the `pc-temp` ntfy topic (change the topic in
   `configuration-additions.yaml` first if you'd rather reuse an existing
   one).

## Verify

- **Developer Tools > States**: confirm `sensor.mini_pc_max_temperature`
  shows a numeric value and updates roughly every 30 seconds.
- **Settings > Automations**: open "Mini PC - High Temperature Alert" and
  use **Run actions** to confirm the ntfy notification arrives.
- Adjust the 80°C threshold in the automation to whatever's appropriate
  for this specific hardware's thermal limits.

## Promotion to V2

Once verified:
- The HA config changes stay on the host as-is (gitignored runtime state
  either way).
- Remove `Docker/V3/pc-temperature-alerting/` and its row in
  `Docker/V3/README.md`.
- Optionally add a short note to
  `Docker/V2/guides/stacks/dashboards-automation-guide.md` describing the
  sensor/automation for future reference.

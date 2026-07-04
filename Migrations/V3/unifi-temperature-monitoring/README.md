# UniFi Switch / UDM Pro Temperature Monitoring (unpoller)

**Status: staged, not deployed.** Blocked on creating a local read-only
UniFi account and choosing the UDM Pro's controller URL -- no hardware
purchase needed.

## What This Is

`unpoller` is a small container that polls the UniFi Network controller
(running on the UDM Pro) over its local API and re-exports the data as
Prometheus metrics, including `unpoller_device_temperature_celsius` per
device (labeled by device `name`, `temp_area`, and `temp_type`). This is
more detailed than Home Assistant's built-in `UniFi Network` integration,
which only exposes a single general "device temperature" sensor per
device with unclear per-model coverage.

Because this data lands in Prometheus, alerting goes through Grafana
(already deployed, already pointed at this Prometheus) instead of Home
Assistant -- a second, separate alerting surface from the ntfy automations
already built into HA for the rack sensor and mini PC temperature. This is
a deliberate tradeoff: richer data and reuse of existing infrastructure,
at the cost of alerting logic being split across two tools instead of one.

```
UDM Pro controller API --> unpoller --> Prometheus (new scrape target) -->
  Grafana alert rule --> webhook contact point --> ntfy
```

## What's In This Folder

| File | Purpose |
|------|---------|
| `compose/unpoller-service-addition.yaml` | New `unpoller` service to add to `dashboards-automation`'s `compose.yaml` |
| `compose/env-additions.txt` | New `.env` / `.env.example` variables it needs |
| `prometheus/scrape-config-addition.yml` | New scrape job to add to `prometheus.yml` |

There's no Home Assistant config here -- this item alerts through Grafana,
per the tradeoff above.

## Create a Read-Only UniFi Account

Create a local account on the UDM Pro dedicated to this poller, not your
normal admin login, so a leaked container credential can't do more than
read statistics:

1. In the UniFi Network application: **Settings > Admins & Users** (menu
   wording varies by firmware version -- look for account/team
   management).
2. Add a local (not cloud SSO) account, and assign it the most restricted
   role available that still permits statistics access -- typically a
   "Viewer" / "Limited" / "Read Only" role, not "Super Admin" or "Admin."
3. Use these credentials as `UNIFI_POLLER_USER` / `UNIFI_POLLER_PASS`.

Confirm the exact role name and permissions in your controller's current
UI before finishing -- it's changed naming across UniFi OS versions.

## Setup

1. Create the read-only account above.
2. Find the UDM Pro's controller URL. For UniFi OS devices (UDM, UDM Pro,
   UDM SE, UXG) this is `https://<its-ip>` with **no** `:8443` suffix --
   that port is only for older, non-UniFi-OS controllers.
3. Add the variables in `compose/env-additions.txt` to
   `dashboards-automation`'s `.env` (real values) and `.env.example`
   (blank template).
4. Add the `unpoller` service block from
   `compose/unpoller-service-addition.yaml` into `compose.yaml`.
5. Add the scrape job from `prometheus/scrape-config-addition.yml` into
   `prometheus.yml` -- see the note in that file about a pre-existing
   compose.yaml/prometheus.yml mount-path mismatch worth confirming first.
6. `docker compose up -d` in `dashboards-automation`.
7. Confirm metrics are flowing:
   ```bash
   curl -s http://192.168.11.10:9130/metrics | grep unpoller_device_temperature_celsius
   ```
   Then confirm Prometheus is scraping it: **Status > Targets** in
   Prometheus should show `unpoller` as `UP`.

## Wire Up Grafana Alerting

### 1. Contact point

**Alerting > Contact points > + Create Contact point**
- Name: `ntfy-unifi`
- Integration: **Webhook**
- URL: `http://ntfy:80/unifi-alerts` (Grafana and ntfy are both on
  `proxy_net`, so this resolves by container name)
- HTTP Method: `POST`
- Under **Optional Webhook settings > Payload**, set a custom JSON body,
  e.g.:
  ```
  {
    "topic": "unifi-alerts",
    "title": "UniFi Device Alert",
    "message": "{{ .Status }}: {{ range .Alerts }}{{ .Labels.name }} {{ .Labels.temp_area }} is hot; {{ end }}",
    "priority": 4,
    "tags": "warning,satellite"
  }
  ```
  Grafana sends `Content-Type: application/json` by default when a custom
  payload is set, which is what ntfy's JSON publish endpoint expects. Use
  Grafana's built-in payload preview to check the rendered output and
  adjust the template -- the exact fields available on `.Alerts` entries
  are worth confirming against your Grafana version's templating
  reference before relying on this verbatim.

### 2. Alert rule

**Alerting > Alert rules > New alert rule**
- Data source: Prometheus
- Query: `unpoller_device_temperature_celsius`
- Condition: fire when the value is above a threshold -- start around
  **70°C** as a conservative default and tune it once you've seen normal
  operating temperatures for your specific switch models and the UDM Pro
  (values vary meaningfully by hardware; this is a starting point, not a
  spec).
- Evaluation: every `1m`, for `5m` before firing (matches the pattern used
  for the rack and PC temp alerts).
- Contact point: `ntfy-unifi`

### 3. Subscribe

Subscribe to the `unifi-alerts` ntfy topic (change the topic name in both
the contact point URL and its payload if you'd rather use a different
one).

## Verify

- Prometheus **Status > Targets**: `unpoller` shows `UP`.
- Grafana **Explore**: query `unpoller_device_temperature_celsius` and
  confirm values for your switches and the UDM Pro appear.
- Use the alert rule's **Preview** / test-firing tools in Grafana to
  confirm the ntfy notification arrives before relying on a real
  threshold breach.

## Promotion

Once verified:
- Merge the `unpoller` service into
  `Docker/stacks/dashboards-automation/compose.yaml` and its variables
  into that stack's real `.env.example`.
- Merge the scrape job into
  `Docker/stacks/dashboards-automation/prometheus/prometheus.yml`.
- Add a short section to
  `Guides/stacks/dashboards-automation-guide.md` covering
  `unpoller` and the Grafana alert rule (Grafana alert rules and contact
  points live in Grafana's own database, not a repo file, so the guide
  should document how to recreate them, not just point at a config file).
- Remove `Migrations/V3/unifi-temperature-monitoring/` and its row in
  `Migrations/V3/README.md`.

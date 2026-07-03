# Homepage config -- remaining setup

These files are already in place at
`V2/stacks/dashboards-automation/homepage/config/`, matching the
`./homepage/config:/app/config` volume mount in `compose.yaml`, and the
Docker socket mount and `HOMEPAGE_VAR_*` environment wiring are already
in `compose.yaml`. What's left is filling in host-specific values:

## 1. Fill in the placeholders

- **`widgets.yaml`** -- replace the `latitude`/`longitude`/`timezone` with
  your real location (currently placeholder DC-area coordinates).
- **`services.yaml`** -- the `{{HOMEPAGE_VAR_*}}` entries (Immich,
  Jellyfin, Pi-hole widgets) need API keys. Add them to
  `dashboards-automation/.env`:
  ```
  HOMEPAGE_VAR_IMMICH_KEY=
  HOMEPAGE_VAR_JELLYFIN_KEY=
  HOMEPAGE_VAR_PIHOLE_KEY=
  ```
  If you'd rather skip the live widgets for now, just delete the
  `widget:` block under that service -- the card still works as a link.
- Container names in `services.yaml` (e.g. `container: immich_server`)
  assume standard names from your compose files -- double check against
  your actual `container_name:` values and adjust any that differ.

## 2. Restart

```bash
docker compose up -d homepage
```

## 3. Match the exact look

`custom.css` gets you close, but Homepage's internal class names shift
between versions. Once it's running, open devtools on the live page and
confirm the status-pill and search-bar selectors actually match what's
rendered -- tweak the handful of classes flagged with comments in the
CSS file if needed.

## Not carried over from the mockup

The screenshot's `Inference` AI section (acestep, dia, flux2-klein,
nemotron, etc.) and the `Cluster` section (Headlamp, Longhorn, Kube Ops
View) are Kubernetes/GPU-cluster tooling not currently run here -- the
`AI` group only has Ollama + Open WebUI, matching the README.

# Wiring this into your homelab repo

These 5 files go straight into your existing `dashboards-automation` stack:

```
V2/stacks/dashboards-automation/homepage/config/
├── settings.yaml
├── widgets.yaml
├── docker.yaml
├── services.yaml
└── custom.css
```

That path matches `dashboards-automation/homepage/config/` in your
`compose.yaml` volume mount, per the README's directory structure.

## 1. Copy the files

On your dev machine (`C:\Workspace\Source\Configs\homelab\V2`):

```
V2\stacks\dashboards-automation\homepage\config\
```

Drop all 5 files there, commit, then pull on the host per your
`git-deployment-guide.md` workflow.

## 2. Mount the Docker socket (for live RUNNING/STOPPED status)

If not already present, add to `homepage` in
`dashboards-automation/compose.yaml`:

```yaml
services:
  homepage:
    volumes:
      - ./homepage/config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

## 3. Fill in the placeholders

- **`widgets.yaml`** — replace the `latitude`/`longitude`/`timezone` with
  your real location (currently placeholder DC-area coordinates).
- **`services.yaml`** — the `{{HOMEPAGE_VAR_*}}` entries (Immich,
  Jellyfin, Pi-hole widgets) need API keys. Add them to
  `dashboards-automation/.env`:
  ```
  HOMEPAGE_VAR_IMMICH_KEY=
  HOMEPAGE_VAR_JELLYFIN_KEY=
  HOMEPAGE_VAR_PIHOLE_KEY=
  ```
  If you'd rather skip the live widgets for now, just delete the
  `widget:` block under that service — the card still works as a link.
- Container names in `services.yaml` (e.g. `container: immich_server`)
  assume standard names from your compose files — double check against
  your actual `container_name:` values and adjust any that differ.

## 4. Restart

```bash
docker compose up -d homepage
```

## 5. Match the exact look

`custom.css` gets you close, but Homepage's internal class names shift
between versions. Once it's running, open devtools on the live page and
confirm the status-pill and search-bar selectors actually match what's
rendered — tweak the handful of classes flagged with comments in the
CSS file if needed.

## Not carried over from the mockup

The screenshot's `Inference` AI section (acestep, dia, flux2-klein,
nemotron, etc.) and the `Cluster` section (Headlamp, Longhorn, Kube Ops
View) are Kubernetes/GPU-cluster tooling you don't currently run — your
`AI` group here only has Ollama + Open WebUI, which is what your README
actually describes. Happy to flesh out a bigger AI section if/when you
stand more of that up.

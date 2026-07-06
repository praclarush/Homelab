# Homepage Version Banner

**Status: staged, not deployed.** No dependencies -- config-only change.

## What This Is

A static text banner on the Homepage dashboard showing the deployed
homelab version, using Homepage's `greeting` widget (which accepts a
static `text` field instead of its default time-of-day greeting). This
mirrors the root [`README.md`](../../../README.md)'s "Current Version"
section so the version is visible both in the repo and at a glance on
the dashboard.

## What's In This Folder

| File | Purpose |
|------|---------|
| `widgets.yaml` | Full drop-in replacement for `Docker/stacks/dashboards-automation/homepage/config/widgets.yaml` -- every existing widget unchanged, plus the new `greeting` banner prepended |

## Setup

1. Before merging, update the `text:` value in `widgets.yaml` to whatever
   version is actually being promoted (this file was staged against
   `v2.0.1`; it should read the `V2.1` version once that batch ships, not
   `v2.0.1`).
2. Replace `Docker/stacks/dashboards-automation/homepage/config/widgets.yaml`
   entirely with this folder's `widgets.yaml` -- diff it against the live
   file first to confirm nothing else has drifted since this migration was
   written.
3. Config files under `homepage/config/` are bind-mounted and re-read
   without a container recreate -- a plain `docker restart homepage` (or
   even just waiting for Homepage's own file-watcher) picks up the change,
   no `docker compose up -d` needed.

## Verify

Load the dashboard and confirm the banner text at the top of the page
reads the new version.

## Promotion

Once verified:
- Copy `widgets.yaml` over
  `Docker/stacks/dashboards-automation/homepage/config/widgets.yaml`.
- Update the root [`README.md`](../../../README.md) "Current Version"
  section to match.
- Remove `Migrations/V2.1/homepage-version-banner/` and its row in
  `Migrations/V2.1/README.md`.

# proxy_net Network Ownership Mismatch

**Status: known issue, not scheduled.** No files to promote -- this documents
a pre-existing Docker Compose network-ownership mismatch found while
investigating a warning on `infrastructure-networking`'s `docker compose up`,
and stages the fix procedure for whenever a maintenance window allows a
brief full-homelab outage. Not a config bug -- every `compose.yaml` in the
repo already declares the correct ownership.

## What This Is

Per `CLAUDE.md`, `proxy_net` is supposed to be created by
`infrastructure-networking` (`external: false`), with every other stack
except `dockge` joining it as `external: true`. In practice,
`docker network inspect proxy_net` shows it's Docker-labeled as owned by the
`dashboards-automation` Compose project instead:

```
com.docker.compose.project: dashboards-automation
Created:                    2026-07-04T00:35:49Z
```

That timestamp matches initial deployment day, so `dashboards-automation`
was apparently the first stack actually brought up, creating the network
under its own project namespace before `infrastructure-networking` ever
ran. Every `compose.yaml` today has the correct `external:` declarations --
the mismatch is stale metadata on the network object itself, not a bug in
any tracked config.

**Impact today: cosmetic only.** `docker compose up` for
`infrastructure-networking` prints:

```
a network with name proxy_net exists but was not created for project "infrastructure-networking".
Set `external: true` to use an existing network
```

but still attaches successfully -- confirmed by recreating `watchtower`
without issue. `docker compose down` refuses to remove a network with
active endpoints, so this mismatch can't cause an accidental deletion while
any of the containers currently on `proxy_net` (all 46, across all 7
stacks) are running.

## What's In This Folder

Nothing to merge -- this is a procedure note, not a config change.

## Setup / Fix Procedure

Fixing the label requires deleting and recreating `proxy_net`, which means
stopping every container attached to it first -- a brief full-homelab
outage. Do this during a planned maintenance window, not as a drive-by fix:

1. `docker compose down` in every stack directory under
   `/opt/docker/stacks/` except `dockge` (not on `proxy_net`).
2. Confirm `docker network inspect proxy_net` fails, or
   `docker network rm proxy_net` if Compose left it behind.
3. `docker compose up -d` in `infrastructure-networking` first -- this
   recreates `proxy_net` under its own project, matching the documented
   architecture.
4. `docker compose up -d` in every other stack.
5. `docker network inspect proxy_net --format '{{.Labels}}'` should now
   show `com.docker.compose.project: infrastructure-networking`.

## Verify

- Label shows `infrastructure-networking` as the owning project.
- Every previously-running container is back up and healthy
  (`docker ps` across all stacks).
- No more ownership warning on any stack's `docker compose up`.

## Promotion

Once run:

- Remove `Migrations/V2.3/proxy-net-network-ownership/` and its row in
  `Migrations/V2.3/README.md`.
- No `Homelab-wiki` guide update needed -- this is an internal Compose
  bookkeeping fix, not a documented feature or behavior change.

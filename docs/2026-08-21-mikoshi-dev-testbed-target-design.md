# Design: Second Deployment Target (`mikoshi-dev`)

Date: 2026-08-21
Repo: `praclarush/Homelab`
Branch: `task/add-mikoshi-dev-target`
Status: Awaiting review

## Purpose

Add a second deployment target to this repository: an Ubuntu Desktop
machine (`mikoshi-dev`, Dell OptiPlex 5000) that serves as a developer
workstation and as a test bed for validating stack changes before they
reach the production host `mikoshi`. Both hosts deploy from the same
git clone of this repository; nothing about the existing `mikoshi`
deployment changes.

## Confirmed Decisions

| Decision | Value |
|---|---|
| Hostname | `mikoshi-dev` |
| Hardware | Dell OptiPlex 5000, single NIC, Intel integrated graphics |
| OS | Ubuntu Desktop |
| Network | VLAN 60, `192.168.60.10/24`, gateway `192.168.60.1` |
| Stacks deployed | All except `infrastructure-networking` (seven) |
| NAS access | Same Synology shares, mounted read-only |
| Proxy | Prod NPM on `mikoshi` proxies in via `*.lab.home.example.com` |
| Secrets | Freshly generated per host; no prod values copied |
| Expression mechanism | Per-stack `compose.mikoshi-dev.yaml` overrides selected by `COMPOSE_FILE` in `.env` |

Rejected alternatives, with reasons, are in
[Approaches Considered](#approaches-considered).

## Architecture

### Deployment mechanism

Each stack directory already carries a gitignored `.env`. On
`mikoshi-dev`, the five stacks needing an override add one line as the
first entry of that file:

```
COMPOSE_FILE=compose.yaml:compose.mikoshi-dev.yaml
```

Compose reads `COMPOSE_FILE` from the project directory's `.env` as a
CLI configuration variable, so `docker compose up -d` run from the
stack directory layers the override automatically. On `mikoshi` that
line is absent and the override file is never read.

Consequences:

- The operator command is identical on both hosts. No `-f` flags, no
  wrapper scripts, no divergent muscle memory.
- Dockge, which shells out to `docker compose` in the stack directory,
  picks up the override with no configuration of its own.
- Production `compose.yaml` files are not modified at all.

**Verification required at implementation time.** The
`COMPOSE_FILE`-sourced-from-`.env` behavior is documented Compose
behavior but has not been exercised on this host. The first
deployment step on `mikoshi-dev` is `docker compose config` in a stack
with an override, confirming the merged output contains the override's
changes. If it does not resolve, the fallback is an explicit
`COMPOSE_FILE` export in the operator's shell profile; the override
files themselves are unaffected either way.

### Environment contract

`mikoshi-dev` has one network interface, so the repository's three
binding variables collapse:

| Variable | `mikoshi` | `mikoshi-dev` | Rationale |
|---|---|---|---|
| `VLAN11_IP` | `192.168.11.10` | `192.168.60.10` | Single NIC |
| `VLAN61_IP` | `192.168.61.10` | `192.168.60.10` | Single NIC |
| `MESHNET_IP` | `100.124.229.64` | `127.0.0.1` | Not a Meshnet node |
| `DOMAIN` | `home.example.com` | `lab.home.example.com` | Separate proxy namespace |

`VLAN11_IP` and `VLAN61_IP` can safely hold the same address because
no port number in the repository is bound on both. VLAN 61 carries
8081, 25565, 2283, 8096, 13378, and 5000; VLAN 11 carries 9191, 9192,
and everything else. There is no overlap, so no duplicate-binding
error results from collapsing them.

`MESHNET_IP` cannot be collapsed the same way. Ten services bind the
same port on both `MESHNET_IP` and a VLAN variable: 8123
(`homeassistant`), 3003 (`wikijs`), 9925 (`mealie`), 8085
(`paperless-ngx`), 9283 (`grocy`), 5557 (`pottery`), 2283
(`immich-server`), 8096 (`jellyfin`), 13378 (`audiobookshelf`), and
5000 (`kavita`). Setting `MESHNET_IP=127.0.0.1` binds each of those to
loopback, which is a distinct socket from the VLAN address and
therefore not a conflict. It also leaves the service reachable at the
desk without exposing a second LAN listener. Leaving the variable
empty is not viable: the resulting `":3003:3000"` is a compose parse
error.

`DOMAIN` diverges because `homepage` validates incoming requests
against `HOMEPAGE_ALLOWED_HOSTS=homepage.${DOMAIN},${VLAN11_IP}:3000`.
Reaching Homepage at `homepage.lab.home.example.com` requires `DOMAIN`
to be the lab value. That in turn breaks the `websites` stack, which
pulls `registry.${DOMAIN}/pottery:latest` and would resolve to a
registry that does not exist; the `websites` override pins the image
back to the production registry hostname.

### Override files

Five stacks need an override. `dockge` and `llm` need none: they bind
`VLAN11_IP` only, mount no NAS path, and run no backup sidecar.

| Stack | Services disabled | Other changes |
|---|---|---|
| `auth` | `authentik-postgres-backup` | none |
| `dashboards-automation` | `nut-exporter` | none |
| `media-gaming` | `immich-postgres-backup` | `immich-server` upload root remapped |
| `tools` | `wikijs-postgres-backup`, `paperless-postgres-backup`, `linkwarden-postgres-backup`, `backrest` | none |
| `websites` | none | `pottery` image pinned to prod registry |

**Disabling mechanism.** The Compose specification provides no way to
remove a service from a base file via an override. Assigning an
unused profile achieves the same result:

```yaml
services:
  authentik-postgres-backup:
    profiles: ["disabled"]
```

Because the `disabled` profile is never activated, the service is
excluded from `up`, `start`, and `stop`. The merged file still
validates under `docker compose config -q`, so CI coverage is
unaffected.

**Volume remapping.** Compose merges the `volumes` sequence using the
container-side path as the unique key, so an override entry with a
matching target replaces the base entry rather than appending to it.
The `media-gaming` override therefore contains only:

```yaml
services:
  immich-server:
    volumes:
      - /srv/testdata/immich:/usr/src/app/upload
```

`./immich/cache:/usr/src/app/cache` is inherited from the base file
untouched. This merge behavior is confirmed at implementation time
with `docker compose config`.

### NAS access and the Immich exception

The six Synology shares mount at the same paths as on `mikoshi`, with
`ro` in `/etc/fstab`. Read-only enforcement lives in the kernel mount,
not in compose, so a `:rw` bind in a compose file cannot defeat it.
This is deliberate: it means an unreviewed compose change on the test
bed cannot reach production data.

Read-only is compatible with four of the five NAS consumers:

- `jellyfin` already mounts `/media:ro` in the base file.
- `kavita` reads `/books` and writes only to `./kavita/config`.
- `audiobookshelf` reads `/audiobooks` and `/podcasts`, and already
  has `./audiobookshelf/metadata:/metadata` mounted locally, which is
  where it writes by default. No workaround needed.
- The `/mnt/synology/backups` consumers are disabled outright.

It is not compatible with `immich-server`. Its `/usr/src/app/upload`
mount is not an upload inbox; Immich also writes `thumbs/`,
`encoded-video/`, `library/`, and `profile/` beneath that root during
normal operation and at startup. A read-only mount there fails the
container rather than degrading gracefully. The override remaps it to
`/srv/testdata/immich`, a local directory.

The result is an empty Immich instance on the test bed. This is the
correct outcome independent of the read-only constraint: pointing a
second Immich instance with a fresh database at a populated upload
tree causes Immich to reconcile library state against a database that
does not know about the files, which is a known path to data loss.

### Host configuration

New directory `Docker/config/mikoshi-dev/`. Production's host config
files stay flat in `Docker/config/` and are not moved, so the change
is additive.

| File | Contents |
|---|---|
| `netplan-01-mikoshi-dev.yaml` | Single NIC, VLAN 60 untagged, static `192.168.60.10/24`, gateway `192.168.60.1`, `renderer: NetworkManager`, nameserver `192.168.11.10` |
| `fstab` | Six NFS lines with `ro,nofail,_netdev,soft` |
| `README.md` | What differs from the production host configs and why |

Three deliberate divergences from `mikoshi`'s host config:

**`renderer: NetworkManager`, not `networkd`.** Ubuntu Desktop manages
networking through NetworkManager. Netplan still owns
`/etc/netplan/*.yaml` and renders to NetworkManager, so the file
format is unchanged, but the renderer line must match the install or
the configuration is written and never applied.

**Nameserver is `192.168.11.10`, not `127.0.0.1`.** Production points
at its own local Pi-hole. `mikoshi-dev` runs no Pi-hole, so it points
at production's. A secondary consequence is that `systemd-resolved`
stays enabled and untouched on `mikoshi-dev` — the port 53 conflict
that forces disabling it on `mikoshi` does not exist here. That
matters more on Desktop than Server, since NetworkManager's default
configuration depends on `systemd-resolved`.

**`nofail` on every NFS line.** Production uses `defaults`. On a
desktop that is powered off and on daily, and whose NAS access now
crosses a routed VLAN boundary, a mount that cannot complete must not
block boot. Without `nofail`, an unreachable NAS drops the machine to
an emergency shell. `soft` bounds the retry rather than hanging I/O
indefinitely.

Not created for `mikoshi-dev`: `resolv.conf` (systemd-resolved stays
enabled), `crowdsec-firewall-bouncer.yaml` (CrowdSec is not deployed),
`docker-daemon.json` (production's copy applies unchanged and is
referenced from the README). `host-firewall-scoping.sh` is noted in
the README as applicable in reduced form — `node-exporter` and
`rpcbind` are exposed on this host, Pi-hole is not — but is not
written as part of this change.

### Environment example files

Each of the seven deployed stacks gets a tracked
`.env.mikoshi-dev.example` alongside its existing `.env.example`. They
carry the same variable set as production's example with the values
from [Environment contract](#environment-contract), secret fields left
blank for per-host generation, and the `COMPOSE_FILE` line where an
override exists.

This requires one `.gitignore` change. The current rules are:

```
.env
.env.*
!.env.example
```

`.env.*` matches `.env.mikoshi-dev.example`, and `!.env.example` does
not rescue it. Adding `!.env.*.example` after the existing negation
fixes this for any future host as well.

### Scripts

`Scripts/startup-all.sh`, `shutdown-all.sh`, and `rebuild-all.sh` each
hardcode `infrastructure-networking` in `STACK_ORDER`, and
`startup-all.sh` and `rebuild-all.sh` additionally restart
`nginx-proxy-manager` unconditionally at the end. Neither exists on
`mikoshi-dev`.

Change: honor an optional `SKIP_STACKS` environment variable, matching
the existing `STACKS_DIR` override pattern already in all three
scripts, and guard the NPM restart on whether
`infrastructure-networking` actually ran. On `mikoshi-dev` the
operator sets `SKIP_STACKS=infrastructure-networking`; on `mikoshi`
nothing changes.

All three scripts must remain ShellCheck-clean, as enforced by
`.github/workflows/lint-scripts.yaml`.

### CI

`.github/workflows/validate-compose.yaml` gains a second job that
validates merged host configurations, with a matrix over the five
stacks that have overrides. Each step copies
`.env.mikoshi-dev.example` to `.env` and runs
`docker compose -f compose.yaml -f compose.mikoshi-dev.yaml config -q`.
The existing `validate` job is unchanged.

### Documentation

`README.md` gains `mikoshi-dev` in the Physical Devices table and a
short section describing the two-target model and which stacks each
host runs. `CLAUDE.md` gains the same concept, so future sessions do
not assume a single deployment host.

The deployment how-to for `mikoshi-dev` is out of scope for this
repository. Per this repo's own convention, guides belong in
`praclarush/Homelab-wiki`, not here.

## Approaches Considered

**Selected: per-stack override files keyed by `COMPOSE_FILE` in
`.env`.** Zero edits to production compose files. Overrides are
tracked, reviewable, and scoped obviously by filename. Operator
commands are unchanged on both hosts and Dockge works without
configuration. Cost: CI needs a second validation pass, and the
`COMPOSE_FILE`-from-`.env` mechanism needs confirming on first run.

**Rejected: a `Docker/hosts/mikoshi-dev/` profile directory.** Better
as documentation, since the whole test-bed delta is readable in one
folder. Worse as deployment: overrides sit far from their stacks, so
every command needs an explicit `-f ../../hosts/...` path, and Dockge
cannot construct that on its own.

**Rejected: parameterizing the production compose files.** Replacing
hardcoded NAS paths with variables and putting the backup sidecars
behind a `backup` profile would remove the need for override files
entirely, leaving `.env` as the only per-host artifact. It is the
cleanest end state. It was rejected because it lands seven edits in
running production stacks in order to serve a test machine, and the
test machine is what would validate those edits. It remains a
reasonable follow-up once `mikoshi-dev` is proven.

## Prerequisites Outside This Repository

None of these are enforceable from the repository; all block first
deployment.

| Prerequisite | System | Notes |
|---|---|---|
| Reserve `192.168.60.10` on VLAN 60 | Ubiquiti | Same step VLAN 61 needed |
| `docker network create proxy_net` | `mikoshi-dev` | Seven stacks declare it `external: true`; `infrastructure-networking`, which normally creates it, is not deployed here |
| `*.lab.home.example.com` wildcard to `192.168.60.10` | Prod Pi-hole | dnsmasq entry alongside the existing `home.example.com` wildcard |
| `lab.*` proxy hosts | Prod NPM | Optionally via `Scripts/add-npm-proxy-hosts.ps1` |
| `docker login registry.home.example.com` | `mikoshi-dev` | Required for the `websites` stack to pull |
| `/srv/testdata/immich` created and owned appropriately | `mikoshi-dev` | Immich upload root replacement |

NFS exports on the Synology already permit `192.168.60.0/24`, and
inter-VLAN routing between 60 and 61 is in place. Confirmed during
design.

## Risks

**Routed NFS.** Production reaches the NAS same-subnet on a dedicated
NIC. `mikoshi-dev` crosses the gateway for every read. Expect lower
throughput for Jellyfin transcode sources and Immich thumbnail reads.
Acceptable for a test bed; not a model for how production should be
changed.

**Test-bed fidelity gap.** With `infrastructure-networking` absent,
the test bed cannot validate changes to NPM, Pi-hole, CrowdSec,
Watchtower, ntfy, or the Postfix relay. Those six services remain
untestable before production. This is a consequence of the chosen
scope, not a defect in the design, and is the natural candidate for a
later revision if it proves limiting.

**Divergence drift.** Five override files can go stale as the base
compose files change — a service renamed in `compose.yaml` leaves a
dead entry in the override that Compose accepts as a new service
definition. The CI job above catches the common case, since
`docker compose config -q` rejects a service with no `image` or
`build`.

## Explicitly Out of Scope

- Deployment guide for `mikoshi-dev` (belongs in `Homelab-wiki`)
- Developer-workstation tooling on the box (IDEs, runtimes, dotfiles);
  this repository covers the homelab test-bed role only
- Promotion automation between the two hosts
- Three pre-existing gaps, recorded here but deliberately untouched:
  `websites` and `dockge` are absent from the CI matrix in
  `validate-compose.yaml`, and `websites` is absent from `STACK_ORDER`
  in all three scripts under `Scripts/`

## Verification

1. `docker compose config -q` passes for all seven stacks with
   `.env.mikoshi-dev.example` applied, five of them with the override
   layered. Same command CI runs.
2. `docker compose config` on `mikoshi-dev` shows `disabled` profiles
   on all seven intended services (`authentik-postgres-backup`,
   `nut-exporter`, `immich-postgres-backup`, `wikijs-postgres-backup`,
   `paperless-postgres-backup`, `linkwarden-postgres-backup`,
   `backrest`) and `/srv/testdata/immich` as the Immich upload source.
3. `shellcheck` clean on all three modified scripts.
4. `docker compose config -q` still passes for all stacks on
   `mikoshi` with the unchanged production `.env`, proving no
   regression to the production target.

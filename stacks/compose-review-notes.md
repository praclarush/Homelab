# Compose Review Notes

Changes applied during the June 2026 review session. Each entry explains what changed and why.

---

## All stacks — removed `version` field

The top-level `version` field (e.g. `version: '3.8'`) has been obsolete since Docker Compose v2. The Compose specification no longer uses it, and its presence generates a deprecation warning at runtime. Removed from all four compose files.

---

## dashboards-automation — Home Assistant `TZ` environment variable

Added `TZ=America/Chicago` to the `homeassistant` environment block. Home Assistant reads the `TZ` variable for its internal timezone logic (scheduling, automations, timestamps in the UI). The existing `/etc/localtime` bind mount sets the container OS timezone but does not satisfy HA's application-level timezone check. Both are kept; HA needs the env var.

---

## infrastructure-networking — Pi-hole `FTLCONF_webserver_api_password` moved to `.env`

The Pi-hole admin password was hardcoded as a plaintext value in the compose file. Compose files are version-controlled; secrets must not live there. The value is now referenced as `${PIHOLE_PASSWORD}` and must be defined in a `.env` file alongside the compose file. That `.env` is gitignored.

To set up on the host:
```
echo "PIHOLE_PASSWORD=your-password-here" > /opt/docker/stacks/infrastructure-networking/.env
```

## infrastructure-networking — Pi-hole `cap_add: NET_ADMIN`

Pi-hole requires the `NET_ADMIN` capability to manage DNS and DHCP at the network level (manipulating iptables, binding to privileged ports, etc.). Without it, Pi-hole starts but DNS handling silently fails in certain configurations. This is a documented requirement in the Pi-hole Docker image README.

## infrastructure-networking — Watchtower `WATCHTOWER_LABEL_ENABLE=true`

With this flag set, Watchtower only auto-updates containers that have the label `com.centurylinklabs.watchtower.enable=true`. Without it, Watchtower updates every container on the host indiscriminately, including containers managed by other stacks or tools. This opt-in model prevents unintended restarts of services that have not been explicitly marked for auto-update.

To opt a container in, add to its service definition:
```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=true"
```

---

## media-gaming — Removed redundant env vars from `immich-server`

`DB_USERNAME`, `DB_PASSWORD`, and `DB_DATABASE_NAME` were declared both in the `env_file: .env` block and explicitly in the `environment` block. The `env_file` already loads them into the container; the explicit declarations were redundant and created a maintenance hazard (two places to update the same value). Removed the duplicates. `DB_HOSTNAME` and `REDIS_HOSTNAME` are kept explicitly since they are not in `.env`.

## media-gaming — Added `immich-machine-learning` service

Immich ships ML-based features (smart search, face recognition, CLIP embeddings) via a dedicated sidecar container. Without it, those features are unavailable and Immich logs connection errors to `http://immich_machine_learning:3003` on every startup. The `./immich/model-cache:/cache` volume persists downloaded models across container restarts so they do not re-download on each start.

`MACHINE_LEARNING_URL=http://immich_machine_learning:3003` was added to `immich-server` to wire the connection explicitly (matches the Immich default but makes it visible and overridable).

## media-gaming — Health checks on `immich-database` and `immich-redis`

`immich-server` previously declared a simple list-form `depends_on`, which only waits for the dependency container to start -- not for it to be ready to accept connections. On a cold start, Postgres and Redis take several seconds to initialize, and `immich-server` would fail and restart before they were ready.

Health checks added:
- `immich-database`: `pg_isready -d ${POSTGRES_DB} -U ${POSTGRES_USER}` -- confirms Postgres is accepting queries on the expected database.
- `immich-redis`: `redis-cli ping` -- confirms Redis is responsive.

`immich-server` `depends_on` updated to `condition: service_healthy` for both, so it waits until the health checks pass before starting.

## media-gaming — Redis persistence volume `./immich/redis:/data`

Redis by default stores data only in memory. Adding the `/data` volume bind-mount enables AOF/RDB persistence so the Redis job queue survives container restarts. Without it, any Immich background jobs queued at the time of a restart (library scans, thumbnail generation, etc.) are lost and must be re-triggered manually.

---

## Deferred — `immich-database` image migration (do not apply in-place)

The current image `tensorchord/pgvecto-rs:pg14-v0.2.0` is an older community build. Immich now ships its own Postgres image: `ghcr.io/immich-app/postgres:14-vectorchord0.3.0-pgvectors0.2.0`.

This change requires a full database dump and restore -- it is not a rolling upgrade. Do not change the image tag without completing the migration procedure first. Perform at a scheduled maintenance window:

1. `docker exec immich_postgres pg_dumpall -U <DB_USERNAME> > immich_backup.sql`
2. Stop the stack, update the image tag, restart.
3. `docker exec -i immich_postgres psql -U <DB_USERNAME> < immich_backup.sql`
4. Verify Immich starts cleanly before discarding the backup.

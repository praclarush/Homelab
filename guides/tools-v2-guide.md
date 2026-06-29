# Tools Stack v2 Guide

This guide deploys the v2 migration of the `tools` stack, adding
pgAdmin, Stirling PDF, and Mealie to the existing WikiJS deployment.

> **Prerequisite:** The `tools` stack must be running on `compose.yaml`
> before migrating to v2. `dashboards-automation` must be running to
> provide `proxy_net`.

---

## Contents

1. [What v2 Adds](#1-what-v2-adds)
2. [Update the Environment File](#2-update-the-environment-file)
3. [Deploy v2](#3-deploy-v2)
4. [Configure Nginx Proxy Manager](#4-configure-nginx-proxy-manager)
5. [First-Time Service Setup](#5-first-time-service-setup)
6. [Verification Checklist](#6-verification-checklist)

---

## 1. What v2 Adds

| Service | Port | Purpose |
|---------|------|---------|
| pgAdmin | 5050 | Web UI for managing all PostgreSQL instances |
| Stirling PDF | 8083 | Browser-based PDF tools (merge, split, OCR, convert) |
| Mealie | 9925 | Recipe manager with URL import and meal planning |

WikiJS and its PostgreSQL instance carry forward unchanged.

---

## 2. Update the Environment File

Add the following to `/opt/docker/stacks/tools/.env`:

```text
PGADMIN_EMAIL=
PGADMIN_PASSWORD=
```

Use any email address for pgAdmin -- it is the login username, not a
real email. Choose a strong password.

---

## 3. Deploy v2

Bring the stack down and back up with the v2 compose file:

```bash
cd /opt/docker/stacks/tools
docker compose down
cp /path/to/repo/docker/tools/compose.v2.yaml compose.yaml
docker compose up -d
```

WikiJS data is preserved -- the database volume (`./postgres`) is not
touched by the migration.

Verify all services are running:

```bash
docker compose ps
```

Expected: `wikijs`, `wikijs_postgres`, `pgadmin`, `stirling_pdf`, and
`mealie` all show `Up`.

---

## 4. Configure Nginx Proxy Manager

Add three proxy hosts in the NPM admin panel
(`http://192.168.11.10:81`). All use the existing
`*.home.bremmer.zone` wildcard certificate.

| Service | Domain | Forward Host | Port | Websockets |
|---------|--------|-------------|------|-----------|
| pgAdmin | `pgadmin.home.bremmer.zone` | `pgadmin` | 80 | Off |
| Stirling PDF | `pdf.home.bremmer.zone` | `stirling_pdf` | 8080 | Off |
| Mealie | `mealie.home.bremmer.zone` | `mealie` | 9000 | Off |

Use the internal container ports, not the host-mapped ports.

---

## 5. First-Time Service Setup

### pgAdmin

Navigate to `http://192.168.11.10:5050` and log in with the
`PGADMIN_EMAIL` and `PGADMIN_PASSWORD` from your `.env` file.

To add a PostgreSQL server connection, right-click **Servers** and
select **Register > Server**. The connection details for each instance:

| Instance | Host | Port | Database | Username |
|----------|------|------|----------|---------|
| WikiJS | `wikijs_postgres` | 5432 | `wikijs` | value of `DB_USER` |
| Authentik | `authentik_postgres` | 5432 | value of `PG_DB` | value of `PG_USER` |
| Immich | `immich_postgres` | 5432 | value of `DB_DATABASE_NAME` | value of `DB_USERNAME` |

All PostgreSQL containers are on `proxy_net` and reachable from pgAdmin
by container name.

### Stirling PDF

No setup required. Navigate to `http://192.168.11.10:8083` and the
tool is ready to use. OCR support is available for PDF text extraction.

### Mealie

Navigate to `http://192.168.11.10:9925`. The default admin credentials
on first start are:

- Email: `changeme@example.com`
- Password: `MyPassword`

Change these immediately after first login in the admin panel under
**User Settings**.

`ALLOW_SIGNUP=false` is set in the compose file -- only the admin can
create additional accounts.

---

## 6. Verification Checklist

- [ ] `docker compose ps` shows all five containers as `Up`
- [ ] pgAdmin accessible at `http://192.168.11.10:5050`
- [ ] Stirling PDF accessible at `http://192.168.11.10:8083`
- [ ] Mealie accessible at `http://192.168.11.10:9925`
- [ ] NPM proxy hosts created for all three services
- [ ] Mealie default password changed
- [ ] WikiJS still accessible at `https://wiki.home.bremmer.zone`

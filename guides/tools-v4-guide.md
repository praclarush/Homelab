# Tools Stack v4 Guide

This guide deploys the v4 migration of the `tools` stack, adding
Actual Budget and Paperless-ngx to the existing v3 deployment.

> **Prerequisite:** The `tools` stack must be running on `compose.v3.yaml`
> before migrating to v4.

---

## Contents

1. [What v4 Adds](#1-what-v4-adds)
2. [Update the Environment File](#2-update-the-environment-file)
3. [Deploy v4](#3-deploy-v4)
4. [Configure Nginx Proxy Manager](#4-configure-nginx-proxy-manager)
5. [First-Time Service Setup](#5-first-time-service-setup)
6. [Verification Checklist](#6-verification-checklist)

---

## 1. What v4 Adds

| Service | Port | Purpose |
|---------|------|---------|
| Actual Budget | 5006 | Zero-based budgeting and expense tracking |
| Paperless-ngx | 8085 | Document management with OCR and full-text search |
| Paperless PostgreSQL | — | Dedicated database for Paperless (internal) |
| Paperless Redis | — | Paperless task queue (internal) |

All v3 services carry forward unchanged.

---

## 2. Update the Environment File

Add the following to `/opt/docker/stacks/tools/.env`:

```text
PAPERLESS_DB_USER=
PAPERLESS_DB_PASS=
PAPERLESS_SECRET_KEY=
```

Generate `PAPERLESS_SECRET_KEY`:

```bash
openssl rand -hex 32
```

---

## 3. Deploy v4

```bash
cd /opt/docker/stacks/tools
docker compose down
cp /path/to/repo/docker/tools/compose.v4.yaml compose.yaml
docker compose up -d
```

Paperless-ngx waits for its PostgreSQL and Redis health checks before
starting. On a cold start expect 30-60 seconds before the UI is
available.

Verify all services are running:

```bash
docker compose ps
```

---

## 4. Configure Nginx Proxy Manager

| Service | Domain | Forward Host | Port | Websockets |
|---------|--------|-------------|------|-----------|
| Actual Budget | `budget.home.bremmer.zone` | `actual_budget` | 5006 | Off |
| Paperless-ngx | `paperless.home.bremmer.zone` | `paperless_ngx` | 8000 | Off |

---

## 5. First-Time Service Setup

### Actual Budget

Navigate to `http://192.168.11.10:5006`. On first start, Actual Budget
prompts you to create a new budget file. Budget files are stored in
`./actual-budget` and persist across restarts.

### Paperless-ngx

Create the admin account:

```bash
docker exec -it paperless_ngx python3 manage.py createsuperuser
```

Enter a username, email, and password when prompted. Then log in at
`http://192.168.11.10:8085`.

To ingest documents, drop files into `./paperless/consume` on the host.
Paperless monitors this directory and processes new files automatically.
Supported formats include PDF, JPG, PNG, TIFF, and Word documents.

---

## 6. Verification Checklist

- [ ] `docker compose ps` shows all containers as `Up`
- [ ] Actual Budget accessible at `http://192.168.11.10:5006`
- [ ] Paperless-ngx admin account created via `createsuperuser`
- [ ] Paperless-ngx accessible at `http://192.168.11.10:8085`
- [ ] NPM proxy hosts created for both services

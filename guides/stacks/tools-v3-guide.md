# Tools Stack v3 Guide

This guide deploys the v3 migration of the `tools` stack, adding n8n
and IT Tools to the existing v2 deployment.

> **Prerequisite:** The `tools` stack must be running on `compose.v2.yaml`
> before migrating to v3.

---

## Contents

1. [What v3 Adds](#1-what-v3-adds)
2. [Update the Environment File](#2-update-the-environment-file)
3. [Deploy v3](#3-deploy-v3)
4. [Configure Nginx Proxy Manager](#4-configure-nginx-proxy-manager)
5. [First-Time Service Setup](#5-first-time-service-setup)
6. [Verification Checklist](#6-verification-checklist)

---

## 1. What v3 Adds

| Service | Port | Purpose |
|---------|------|---------|
| n8n | 5678 | Workflow automation -- connects services and triggers actions |
| IT Tools | 8084 | Developer utilities (JWT decoder, UUID gen, hash tools, etc.) |

All v2 services carry forward unchanged.

---

## 2. Update the Environment File

Add the following to `/opt/docker/stacks/tools/.env`:

```text
N8N_ENCRYPTION_KEY=
```

Generate the key:

```bash
openssl rand -hex 32
```

This key encrypts stored credentials in n8n. Store it securely -- if
lost, all saved credentials in n8n will need to be re-entered.

---

## 3. Deploy v3

```bash
cd /opt/docker/stacks/tools
docker compose down
cp /path/to/repo/stacks/tools/compose.v3.yaml compose.yaml
docker compose up -d
```

Verify all services are running:

```bash
docker compose ps
```

Expected: all v2 containers plus `n8n` and `it_tools` show `Up`.

---

## 4. Configure Nginx Proxy Manager

| Service | Domain | Forward Host | Port | Websockets |
|---------|--------|-------------|------|-----------|
| n8n | `n8n.home.bremmer.zone` | `n8n` | 5678 | On |
| IT Tools | `it-tools.home.bremmer.zone` | `it_tools` | 80 | Off |

n8n requires websockets enabled for its editor to function correctly.

> **n8n webhook dependency:** The `WEBHOOK_URL` in the compose file is
> set to `https://n8n.home.bremmer.zone`. Create the NPM proxy host
> before configuring any webhook-based workflows, or webhooks will
> fail to register correctly.

---

## 5. First-Time Service Setup

### n8n

Navigate to `http://192.168.11.10:5678`. On first start, n8n prompts
you to create an owner account. Complete the setup wizard before
building any workflows.

n8n stores workflows and credentials in `./n8n` on the host. This
directory is created automatically on first start.

### IT Tools

No setup required. Navigate to `http://192.168.11.10:8084`. All tools
are available immediately with no login.

---

## 6. Verification Checklist

- [ ] `docker compose ps` shows all v2 containers plus `n8n` and `it_tools` as `Up`
- [ ] n8n accessible at `http://192.168.11.10:5678`
- [ ] IT Tools accessible at `http://192.168.11.10:8084`
- [ ] n8n owner account created
- [ ] NPM proxy host for n8n created before configuring webhooks

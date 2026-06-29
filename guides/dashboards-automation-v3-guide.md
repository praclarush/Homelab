# Dashboards-Automation Stack v3 Guide

This guide deploys the v3 migration of the `dashboards-automation` stack,
adding Loki and Promtail to complete the observability stack alongside
the existing Grafana and Prometheus deployment.

> **Prerequisite:** The `dashboards-automation` stack must be running on
> `compose.v2.yaml` before migrating to v3. Copy the Loki and Promtail
> config files to the host before deploying.

---

## Contents

1. [What v3 Adds](#1-what-v3-adds)
2. [Copy Config Files to the Host](#2-copy-config-files-to-the-host)
3. [Deploy v3](#3-deploy-v3)
4. [Add Loki as a Grafana Data Source](#4-add-loki-as-a-grafana-data-source)
5. [Querying Logs in Grafana](#5-querying-logs-in-grafana)
6. [Verification Checklist](#6-verification-checklist)

---

## 1. What v3 Adds

| Service | Port | Purpose |
|---------|------|---------|
| Loki | 3100 | Log aggregation storage and query engine |
| Promtail | — | Log collector -- ships all container and host logs to Loki |

Loki and Promtail complete the Grafana observability stack. Prometheus
handles metrics; Loki handles logs. Both are queried from the same
Grafana instance.

Promtail collects logs from all running containers across all stacks
by reading the Docker socket. It also collects host system logs from
`/var/log`. Logs are labeled by container name, service name, and
stack name for filtering.

No new `.env` variables are required.

---

## 2. Copy Config Files to the Host

Loki and Promtail require config files on the host before the
containers start.

```bash
mkdir -p /opt/docker/stacks/dashboards-automation/loki
mkdir -p /opt/docker/stacks/dashboards-automation/promtail

cp /path/to/repo/docker/dashboards-automation/loki/config.yaml \
   /opt/docker/stacks/dashboards-automation/loki/config.yaml

cp /path/to/repo/docker/dashboards-automation/promtail/config.yaml \
   /opt/docker/stacks/dashboards-automation/promtail/config.yaml
```

---

## 3. Deploy v3

```bash
cd /opt/docker/stacks/dashboards-automation
docker compose down
cp /path/to/repo/docker/dashboards-automation/compose.v3.yaml compose.yaml
docker compose up -d
```

Verify all services are running:

```bash
docker compose ps
```

If Loki or Promtail fail to start, check the config files loaded
correctly:

```bash
docker logs loki
docker logs promtail
```

---

## 4. Add Loki as a Grafana Data Source

Loki stores logs but Grafana must be configured to query it.

1. Navigate to `https://grafana.home.bremmer.zone`
2. Go to **Connections > Data Sources > Add data source**
3. Select **Loki**
4. Set the URL to `http://loki:3100`
5. Click **Save & Test** -- should return "Data source connected and
   labels found"

Loki and Grafana are on the same `proxy_net` network, so Grafana
reaches Loki by container name.

---

## 5. Querying Logs in Grafana

Navigate to **Explore** and select the Loki data source.

Useful LogQL queries:

```logql
# All logs from a specific container
{container="paperless_ngx"}

# All logs from a specific stack
{stack="tools"}

# All logs across all containers
{job="containers"}

# Error-level logs across all containers
{job="containers"} |= "error"

# NPM access logs
{container="nginx_proxy_manager"}
```

To add a logs panel to an existing dashboard, add a new panel, select
the Loki data source, and enter a LogQL query. Logs panels can be
correlated with Prometheus metrics panels on the same dashboard using
shared time ranges.

---

## 6. Verification Checklist

- [ ] Config files copied to host before deploy
- [ ] `docker compose ps` shows all containers as `Up`
- [ ] `docker logs promtail` shows no errors and log lines being shipped
- [ ] Loki data source added to Grafana and connection test passes
- [ ] **Explore** in Grafana returns container logs using `{job="containers"}`
- [ ] Existing v2 services (Grafana, Prometheus, Homepage, etc.) still accessible

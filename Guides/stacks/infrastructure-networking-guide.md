# Infrastructure-Networking Stack Guide

This guide covers CrowdSec intrusion detection and the cross-stack
Watchtower auto-update policy, both in the `infrastructure-networking`
stack. Nginx Proxy Manager and Pi-hole have their own deep-dive guides
under [Networking](../README.md#networking); ntfy and Tailscale
deployment are covered in
[getting-started/homelab-guide.md](../getting-started/homelab-guide.md).

> **Prerequisite:** NPM, Pi-hole, Watchtower, ntfy, and Tailscale must
> already be running, per the getting-started guide. NPM must have
> generated log files before CrowdSec will process anything.

---

## Contents

1. [Watchtower Auto-Update Policy](#1-watchtower-auto-update-policy)
2. [What This Guide Adds](#2-what-this-guide-adds)
3. [Deploy](#3-deploy)
4. [Verify CrowdSec is Running](#4-verify-crowdsec-is-running)
5. [Enroll with the CrowdSec Hub](#5-enroll-with-the-crowdsec-hub)
6. [Install the Firewall Bouncer](#6-install-the-firewall-bouncer)
7. [Ongoing Operations](#7-ongoing-operations)
8. [Verification Checklist](#8-verification-checklist)

---

## 1. Watchtower Auto-Update Policy

Watchtower is deployed as part of the base stack (see the
getting-started guide), but the policy governing what it's allowed to
touch is cross-cutting -- it applies to every stack in this repo, not
just this one -- so it's documented here rather than repeated in each
stack's guide.

Watchtower only updates containers carrying the label
`com.centurylinklabs.watchtower.enable=true`
(`WATCHTOWER_LABEL_ENABLE=true` in `compose.yaml`). Every service across
every stack carries this label **except**: Authentik (`auth`) and its
Postgres/Redis, Immich (`media-gaming`) and its Postgres/Redis, Pi-hole
(this stack), and the standalone Postgres containers for WikiJS,
Paperless-ngx, and Linkwarden (`tools`). Those are excluded because an
unattended update either risks locking you out of SSO-gated services
(Authentik), has a history of breaking database migrations (Immich, Pi-hole's
FTL/config format across major versions), or risks an app/schema version
mismatch between a freshly-updated database and the application
container still running the old client. Update these manually and
deliberately instead:

```bash
docker compose pull <service>
docker compose up -d <service>
```

To opt a new service into auto-update, add the label to its service
definition in `compose.yaml`:

```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=true"
```

---

## 2. What This Guide Adds

| Service | Port | Purpose |
|---------|------|---------|
| CrowdSec | — | Intrusion detection -- reads NPM logs and detects attacks |

CrowdSec has two components:

- **Agent** (this container) -- reads logs, detects attack patterns,
  makes decisions (block/allow). No exposed ports.
- **Bouncer** (installed on the host) -- acts on the agent's decisions
  by blocking IPs at the OS firewall level. Installed separately in
  Section 6.

No new `.env` variables are required. No NPM proxy host is needed.

---

## 3. Deploy

```bash
cd /opt/docker/stacks/infrastructure-networking
docker compose up -d
```

Verify all services are running:

```bash
docker compose ps
```

CrowdSec mounts NPM logs from `./npm/logs` (relative to the stack
directory). If NPM has not generated logs yet, browse to any proxied
service first to produce access log entries.

---

## 4. Verify CrowdSec is Running

Check that CrowdSec started cleanly and loaded the nginx collection:

```bash
docker exec crowdsec cscli collections list
```

Expected output includes `crowdsecurity/nginx` with status `enabled`.

View the log sources CrowdSec is monitoring:

```bash
docker exec crowdsec cscli datasources list
```

---

## 5. Enroll with the CrowdSec Hub

Enrollment is optional but recommended. It enables community threat
intelligence -- blocklists of known malicious IPs shared by other
CrowdSec users.

1. Create a free account at `https://app.crowdsec.net`
2. Go to **Security Engines** and click **Add**
3. Copy the enrollment token
4. Run:

```bash
docker exec crowdsec cscli console enroll <enrollment-token>
```

5. Approve the enrollment in the web console

After enrollment, CrowdSec downloads community blocklists automatically.
View active blocklists:

```bash
docker exec crowdsec cscli hub list
```

---

## 6. Install the Firewall Bouncer

The firewall bouncer blocks IPs at the OS level using nftables. It runs
on the host, not in Docker, so it can block traffic before it reaches
any container.

Install the bouncer package:

```bash
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | sudo bash
sudo apt install crowdsec-firewall-bouncer-nftables
```

Register the bouncer with the CrowdSec agent to get an API key:

```bash
docker exec crowdsec cscli bouncers add firewall-bouncer
```

Copy the output API key. Edit the bouncer config:

```bash
sudo nano /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
```

Set these two values:

```yaml
api_url: http://localhost:8080
api_key: <paste key here>
```

This file is otherwise generated by the package installer -- a
reference copy showing just these two override values (with a note on
why the rest isn't reproduced) is at
[`config/crowdsec-firewall-bouncer.yaml`](../../Docker/config/crowdsec-firewall-bouncer.yaml).

Start the bouncer:

```bash
sudo systemctl enable --now crowdsec-firewall-bouncer
```

Verify it is running:

```bash
sudo systemctl status crowdsec-firewall-bouncer
```

---

## 7. Ongoing Operations

View detected alerts (attacks CrowdSec identified):

```bash
docker exec crowdsec cscli alerts list
```

View active decisions (IPs currently blocked):

```bash
docker exec crowdsec cscli decisions list
```

Manually ban an IP:

```bash
docker exec crowdsec cscli decisions add --ip 1.2.3.4 --reason "manual ban"
```

Remove a ban:

```bash
docker exec crowdsec cscli decisions delete --ip 1.2.3.4
```

Add additional collections (e.g., for Home Assistant logs):

```bash
docker exec crowdsec cscli collections install crowdsecurity/home-assistant
```

Then restart CrowdSec to load the new collection:

```bash
docker compose restart crowdsec
```

---

## 8. Verification Checklist

- [ ] `docker compose ps` shows all containers as `Up`
- [ ] `cscli collections list` shows `crowdsecurity/nginx` as enabled
- [ ] `cscli datasources list` shows NPM log path being monitored
- [ ] CrowdSec hub enrollment completed (optional)
- [ ] Firewall bouncer installed and running on host
- [ ] `cscli decisions list` returns without error
- [ ] Existing services (NPM, Pi-hole, Watchtower, ntfy, Tailscale) still accessible

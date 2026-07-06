# Infrastructure-Networking Stack Guide

This guide covers CrowdSec intrusion detection, the SMTP relay, and the
cross-stack Watchtower auto-update policy, all in the
`infrastructure-networking` stack. Nginx Proxy Manager and Pi-hole have
their own deep-dive guides under
[Networking](../README.md#networking); ntfy and Tailscale deployment
are covered in
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
8. [SMTP Relay](#8-smtp-relay)
9. [Verification Checklist](#9-verification-checklist)

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
| Postfix Relay | 25 | Unauthenticated local SMTP relay for LAN devices, forwarding to Gmail -- see [Section 8](#8-smtp-relay) |

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

## 8. SMTP Relay

`boky/postfix` (`postfix-relay` service, container `postfix_relay`)
accepts unauthenticated mail on port 25 from trusted LAN subnets and
relays it out through Gmail over authenticated SMTP, for devices like
the Synology NAS that can't hold a Gmail app password or do STARTTLS
themselves:

```
NAS / other LAN device --> postfix-relay (VLAN11_IP:25, no auth) -->
  smtp.gmail.com:587 (authenticated) --> your inbox
```

**Setup:**

1. Generate a Gmail app password (requires 2FA on the account):
   myaccount.google.com/apppasswords -> create one for "Mail".
2. Set `SMTP_RELAY_USERNAME` (your Gmail address) and
   `SMTP_RELAY_PASSWORD` (the 16-character app password) in this
   stack's `.env`.
3. `ALLOWED_SENDER_DOMAINS=home.bremmer.zone` in `compose.yaml`
   restricts relaying to envelope senders in that domain -- point any
   new LAN device's SMTP client at `192.168.11.10:25`, no encryption,
   no auth, with a `from` address under `home.bremmer.zone`.
4. `MYNETWORKS` in `compose.yaml` is set explicitly to
   `127.0.0.0/8,192.168.11.0/24,192.168.61.0/24` (VLANs 11 and 61),
   overriding the image's own auto-detected default. If another
   container on `proxy_net` needs to relay by container name rather
   than `VLAN11_IP`, add `proxy_net`'s actual subnet too -- confirm it
   with `docker network inspect proxy_net` first, since it isn't
   pinned to a fixed CIDR in `compose.yaml`.

**Verify:**

`boky/postfix` is relay-only -- it has no MUA (`mail`/`mailx`), only
Postfix's own `sendmail` binary. Use `-f` to set an envelope sender in
`home.bremmer.zone`, or the default `root@<container>` sender gets
rejected by `ALLOWED_SENDER_DOMAINS` before it reaches Gmail:

```bash
docker exec -it postfix_relay sh -c "printf 'Subject: relay test\n\ntest body\n' | sendmail -f test@home.bremmer.zone you@gmail.com"
```

Check `docker logs postfix_relay` if it doesn't arrive. Besides a bad
app password, a common failure is `status=deferred ... Name service
error for name=smtp.gmail.com`: this means the *host's* DNS is broken,
not Postfix's config -- see the `resolv.conf` note in
[`Docker/config/README.md`](../../Docker/config/README.md). Disabling
`systemd-resolved` (Section 2.1 of the getting-started guide) leaves
`/etc/resolv.conf` a dangling symlink, which silently breaks external
DNS resolution for every container on the host, not just this one.

Once verified, point the NAS's (or other device's) SMTP notification
settings at `192.168.11.10:25`, no encryption, no auth, and trigger a
real test notification from its UI.

If Gmail starts throttling or bouncing mail from this relay, swap
`RELAYHOST`/`RELAYHOST_USERNAME`/`RELAYHOST_PASSWORD` for a dedicated
transactional provider (Brevo, Mailgun, SES) instead -- same Postfix
config, different relayhost.

---

## 9. Verification Checklist

- [ ] `docker compose ps` shows all containers as `Up`
- [ ] `cscli collections list` shows `crowdsecurity/nginx` as enabled
- [ ] `cscli datasources list` shows NPM log path being monitored
- [ ] CrowdSec hub enrollment completed (optional)
- [ ] Firewall bouncer installed and running on host
- [ ] `cscli decisions list` returns without error
- [ ] `sendmail` test from `postfix_relay` arrives in the target inbox
- [ ] A real LAN device (e.g. the NAS) can send mail through the relay
- [ ] Existing services (NPM, Pi-hole, Watchtower, ntfy, Tailscale) still accessible

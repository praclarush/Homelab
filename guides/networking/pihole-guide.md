# Pi-hole Configuration Guide

This guide covers Pi-hole end to end: deployment, handing DNS duty to it
network-wide, local DNS records, the wildcard record that backs the
`*.home.bremmer.zone` proxy domain, blocklist maintenance, and backup.
Pi-hole runs as part of the `infrastructure-networking` stack alongside
Nginx Proxy Manager, Watchtower, ntfy, Tailscale, and (from v3) CrowdSec.

---

## Contents

1. [How Pi-hole Fits This Network](#1-how-pi-hole-fits-this-network)
2. [Prerequisites](#2-prerequisites)
3. [Environment File](#3-environment-file)
4. [Deployment](#4-deployment)
5. [First-Time Login](#5-first-time-login)
6. [Point Network DNS at Pi-hole](#6-point-network-dns-at-pi-hole)
7. [Local DNS Records](#7-local-dns-records)
8. [Wildcard DNS for the Proxy Domain](#8-wildcard-dns-for-the-proxy-domain)
9. [Blocklist (Gravity) Management](#9-blocklist-gravity-management)
10. [Backup and Restore (Teleporter)](#10-backup-and-restore-teleporter)
11. [Maintenance and Troubleshooting](#11-maintenance-and-troubleshooting)
12. [Verification Checklist](#12-verification-checklist)

---

## 1. How Pi-hole Fits This Network

Pi-hole is the network's DNS resolver. Every VLAN's DHCP server hands out
the mini PC's VLAN 11 IP (`192.168.11.10`) as the DNS server, so every
client query passes through Pi-hole before reaching the internet. This
gets you two things:

- **Ad and tracker blocking** -- queries to known ad/tracker domains are
  answered with `0.0.0.0` instead of being forwarded.
- **Split-horizon DNS for the proxy domain** -- a single wildcard record
  makes every `*.home.bremmer.zone` subdomain resolve to Nginx Proxy
  Manager's IP internally, without any public DNS record existing. See
  `nginx-proxy-manager-guide.md` for the full reverse-proxy setup that
  depends on this.

Pi-hole listens on port 53 for DNS and port 80 internally for its web
admin (exposed on the host as `8080`).

---

## 2. Prerequisites

### 2.1 Free Port 53 on the Host

Pi-hole needs exclusive use of port 53. On Ubuntu/Debian,
`systemd-resolved` binds it by default and must be disabled first:

```bash
sudo systemctl is-active systemd-resolved
```

If the output is `active`:

```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

Confirm port 53 is free:

```bash
sudo ss -tulnp | grep :53
```

The output should be empty. If anything is still listed, stop that
process before deploying.

### 2.2 VLAN 11 IP Assigned

Pi-hole's web admin port binds to `${VLAN11_IP}` specifically (not
`0.0.0.0`). The `eth0.11` interface must already be configured with its
static IP -- see `../getting-started/homelab-v1-guide.md` section 2.5 if
this has not been done.

---

## 3. Environment File

`infrastructure-networking/.env` needs:

```text
PIHOLE_PASSWORD=your-pihole-admin-password
VLAN11_IP=192.168.11.10
```

Replace `192.168.11.10` with your actual VLAN 11 IP. Choose a strong
`PIHOLE_PASSWORD` -- this becomes the web admin login and the API
password, and the admin interface is reachable by anything on VLAN 11.

> **Password changes don't take effect after first start.** The
> `pihole/pihole` image (Pi-hole v6 / FTL) only applies
> `FTLCONF_webserver_api_password` the first time it initializes
> `/etc/pihole`. Editing `.env` and restarting the container later has
> no effect, because the password is already stored in
> `pihole/config/pihole.toml`. To change the password after initial
> deployment, use the `pihole setpassword` command (section 11) instead
> of editing `.env`.

---

## 4. Deployment

The relevant service from `compose.yaml`:

```yaml
pihole:
  container_name: pihole
  image: pihole/pihole:latest
  cap_add:
    - NET_ADMIN
  ports:
    - "0.0.0.0:53:53/tcp"
    - "0.0.0.0:53:53/udp"
    - "${VLAN11_IP}:8080:80/tcp"
  environment:
    - TZ=America/Chicago
    - FTLCONF_webserver_api_password=${PIHOLE_PASSWORD}
    - FTLCONF_dns_listeningMode=all
  volumes:
    - ./pihole/config:/etc/pihole
    - ./pihole/dnsmasq:/etc/dnsmasq.d
  restart: unless-stopped
  networks:
    - proxy_net
```

DNS ports (53/tcp, 53/udp) are bound to all interfaces so every VLAN can
reach them. The web admin port is scoped to the VLAN 11 IP only.
`FTLCONF_dns_listeningMode=all` is required for Pi-hole to accept
queries arriving from VLANs other than the one Docker's bridge sits on
-- without it, Pi-hole only answers queries that appear to originate
from its own container subnet and clients on other VLANs get no
response. Adjust `TZ` if you are not in `America/Chicago`.

Deploy:

```bash
cd /opt/docker/stacks/infrastructure-networking
docker compose up -d
```

Pi-hole takes 20-30 seconds to initialize on first start (gravity
database build). Confirm it's running:

```bash
docker compose ps pihole
```

Watch first-start logs if it doesn't come up clean:

```bash
docker compose logs pihole
```

---

## 5. First-Time Login

1. Open `http://192.168.11.10:8080/admin`
2. Log in with `PIHOLE_PASSWORD` from your `.env` file
3. The dashboard shows query statistics -- empty until clients start
   using Pi-hole for DNS (next section)

---

## 6. Point Network DNS at Pi-hole

In the Ubiquiti controller:

1. Go to **Settings > Networks**
2. For each VLAN (11, 20, 30, 31, 40, 50, 60, 61) -- see
   [`vlan-reference.md`](vlan-reference.md) for the full list:
   - Click the VLAN to edit it
   - Under **DHCP**, set **DNS Server 1** to `192.168.11.10` (your
     VLAN 11 IP)
   - Save

Existing leases pick up the new DNS server on their next DHCP renewal.
To force it immediately on a device, release/renew the lease (or
reconnect to Wi-Fi).

Test from a Windows machine:

```powershell
nslookup google.com 192.168.11.10
```

This should return a public IP. If it times out, Pi-hole isn't
reachable on port 53 from that VLAN -- check the prerequisite in
section 2.1 and confirm `FTLCONF_dns_listeningMode=all` is set.

---

## 7. Local DNS Records

Use these for one-off internal hostnames that don't fit the wildcard
pattern in section 8 (e.g. pointing a hostname at the NAS or another
non-Docker device).

**Via the web UI:**

1. Go to **Local DNS > DNS Records**
2. Add a domain (e.g. `nas.home`) and the IP it should resolve to
3. Click the **+** button to save

**Via a dnsmasq config file** (useful for records you want tracked in
the repo, or for bulk entries):

```bash
sudo nano /opt/docker/stacks/infrastructure-networking/pihole/dnsmasq/01-custom-hosts.conf
```

```text
address=/nas.home/192.168.60.5
address=/printer.home/192.168.11.50
```

Reload Pi-hole's resolver after editing any dnsmasq file directly:

```bash
docker exec pihole pihole restartdns
```

---

## 8. Wildcard DNS for the Proxy Domain

This single record is what lets every `*.home.bremmer.zone` service
resolve internally without per-service DNS entries. Full reverse-proxy
context is in `nginx-proxy-manager-guide.md` section 4 -- this section
covers just the Pi-hole side.

```bash
sudo nano /opt/docker/stacks/infrastructure-networking/pihole/dnsmasq/02-local-dns.conf
```

```text
address=/.home.bremmer.zone/192.168.11.10
```

Reload:

```bash
docker exec pihole pihole restartdns
```

Test:

```powershell
nslookup anything.home.bremmer.zone 192.168.11.10
```

Should return `192.168.11.10`. Any new service added behind NPM
resolves automatically -- no further Pi-hole changes are needed.

> **This file lives on the host, not in Docker's writable layer.** If
> the `pihole` container is ever recreated (e.g. `docker compose down`
> followed by `up`), this file survives because `./pihole/dnsmasq` is a
> bind mount. If wildcard resolution stops working after a container
> recreation, check that the file is still present before assuming
> Pi-hole itself is broken.

---

## 9. Blocklist (Gravity) Management

Pi-hole blocks ads/trackers using "adlists" -- subscribed blocklists
compiled into a local database called gravity.

**View/add adlists:** **Adlists** in the left menu. The default StevenBlack
list is added automatically on first start.

**Force a gravity rebuild** (after adding/removing an adlist, or to
pick up upstream list updates):

```bash
docker exec pihole pihole -g
```

**Allow or block a specific domain** (Pi-hole v6 renamed the old
`whitelist`/`blacklist` commands to `allow`/`deny`):

```bash
docker exec pihole pihole allow add example.com
docker exec pihole pihole deny add ads.example.com
```

Equivalent controls exist in the web UI under **Domains**.

**Per-client or per-group blocking** (e.g. stricter rules for VLAN 60
Personal devices, looser for VLAN 11): configure under **Group
Management**, then assign clients to groups under **Clients**.

---

## 10. Backup and Restore (Teleporter)

Teleporter exports Pi-hole's full configuration (adlists, local DNS
records, groups, settings) as a single archive.

**Backup:**

1. Go to **Settings > Teleporter**
2. Click **Backup** -- downloads a `.zip` archive

Store this alongside your other stack backups (see the README's
Backup section) -- it is not covered by the `./pihole/config` volume
backup alone in a way that's easy to selectively restore from.

**Restore:**

1. Go to **Settings > Teleporter**
2. Under **Restore**, choose the archive and click **Restore**
3. Pi-hole restarts its FTL process to apply the import

---

## 11. Maintenance and Troubleshooting

**Reset the admin password** (does not require touching `.env`):

```bash
docker exec pihole pihole setpassword your-new-password
```

**DNS not resolving anywhere:**

```bash
docker compose ps pihole
docker compose logs pihole
sudo ss -tulnp | grep :53
```

If another process is holding port 53, Pi-hole's container will show
as `Restarting` -- re-check section 2.1.

**DNS resolves locally on the host but not from other VLANs:** confirm
`FTLCONF_dns_listeningMode=all` is present in the compose file's
environment block. Without it, Pi-hole only answers Docker-bridge-local
queries.

**Wildcard or custom DNS entries stopped working:** the dnsmasq config
files in `./pihole/dnsmasq` may not have survived a container
recreation if that directory's bind mount path changed. Verify the
files exist on the host, then:

```bash
docker exec pihole pihole restartdns
```

**Updating the image:**

```bash
cd /opt/docker/stacks/infrastructure-networking
docker compose pull pihole
docker compose up -d pihole
```

Watchtower will not auto-update Pi-hole: `WATCHTOWER_LABEL_ENABLE=true`
restricts Watchtower to labeled containers only, and the `pihole`
service in `compose.yaml` carries no
`com.centurylinklabs.watchtower.enable` label. Pull/restart manually as
shown above to update.

---

## 12. Verification Checklist

| Item | How to Verify |
|------|--------------|
| Pi-hole container running | `docker compose ps pihole` shows `running` |
| Port 53 free of conflicts before start | `sudo ss -tulnp \| grep :53` shows only Pi-hole after deploy |
| Web admin loads | `http://192.168.11.10:8080/admin` |
| Admin login works | Log in with `PIHOLE_PASSWORD` (or password set via `pihole setpassword`) |
| Public DNS resolves through Pi-hole | `nslookup google.com 192.168.11.10` from Windows returns an IP |
| All VLANs use Pi-hole for DNS | Ubiquiti DHCP settings show `192.168.11.10` as DNS Server 1 for every VLAN |
| Wildcard proxy domain resolves | `nslookup anything.home.bremmer.zone 192.168.11.10` returns `192.168.11.10` |
| Local DNS records resolve | `nslookup <your-record> 192.168.11.10` returns the configured IP |
| Gravity (blocklists) populated | Dashboard shows a non-zero "Domains on Adlists" count |
| Teleporter backup exists | A recent `.zip` export is stored outside the host (off-box backup) |

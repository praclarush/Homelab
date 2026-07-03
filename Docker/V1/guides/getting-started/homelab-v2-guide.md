# Homelab v2 Configuration Guide

This guide walks through migrating existing v1 stacks to v2 and
deploying the new `auth` and `tools` stacks. It assumes you have already completed
the v1 setup guide and have all four v1 stacks running.

> **Prerequisite:** The trunk port and VLAN sub-interface configuration
> from v1 guide step 2.5 must be complete before deploying v2. The v2
> compose files bind services to specific VLAN IPs (`eth0.11` and
> `eth0.61`). If those interfaces do not exist, Docker will fail to
> start any container with a bound port.

It is written for someone comfortable with Windows IT concepts who may
be newer to Linux. If a Linux concept needs clarification, refer back
to the **Working on Linux from Windows** section in the v1 guide.

---

## Contents

1. [What Changes in v2](#1-what-changes-in-v2)
2. [NordVPN Meshnet — Remote Access](#2-nordvpn-meshnet--remote-access)
3. [Generating Secrets](#3-generating-secrets)
4. [Updating Environment Files](#4-updating-environment-files)
5. [Copying Config Files to the Host](#5-copying-config-files-to-the-host)
6. [Migrating Existing Stacks to v2](#6-migrating-existing-stacks-to-v2)
7. [Deploying the Auth Stack](#7-deploying-the-auth-stack)
8. [Deploying the Tools Stack](#8-deploying-the-tools-stack)
9. [First-Time Service Setup](#9-first-time-service-setup)
10. [Verification Checklist](#10-verification-checklist)

---

## 1. What Changes in v2

v2 adds the following services to existing stacks:

| Stack | New services |
|-------|-------------|
| dashboards-automation | Uptime Kuma, Grafana, Prometheus, node-exporter |
| infrastructure-networking | ntfy, Tailscale |
| media-gaming | Jellyfin |
| auth (new stack) | Authentik, PostgreSQL, Redis |
| tools (new stack) | WikiJS, PostgreSQL |

Services removed in v2: **wg-easy** and **Vaultwarden** (replaced by
NordVPN Meshnet and Keeper respectively).

Each existing stack has a `compose.v2.yaml` file in the repository. The
migration process is: bring the stack down, bring it back up with the
v2 file. Data volumes are preserved -- nothing is lost.

---

## 2. NordVPN Meshnet — Remote Access

Meshnet is a feature of your existing NordVPN subscription that lets
your devices connect directly to each other without port forwarding.
Think of it like a VPN that you run for your own devices rather than
routing through NordVPN's servers. This is how you will access the
homelab remotely.

This is set up on the host itself, outside Docker, before any compose
changes.

### 2.1 Install NordVPN on the Mini PC Host

Connect to the host over SSH and run:

```bash
sh <(curl -sSf https://downloads.nordvpn.com/apps/linux/install.sh)
```

This downloads and runs the NordVPN installer. When it finishes, log
in to your NordVPN account:

```bash
nordvpn login
```

A browser link will appear in the terminal. Copy it, open it in your
browser, complete the login, then return to the terminal. You should
see `Welcome to NordVPN`.

### 2.2 Enable Meshnet on the Host

```bash
nordvpn set meshnet on
```

Check that it is active:

```bash
nordvpn meshnet status
```

The output should include `Meshnet: enabled` and a Meshnet IP address
for this machine (it will be in the `100.64.x.x` range, similar to how
Tailscale assigns IPs). This is the address you will use to reach the
homelab from other devices.

### 2.3 Enable Meshnet on Your Other Devices

On each device you want to connect from (your Windows laptop, phone,
etc.):

1. Open the NordVPN app
2. Navigate to **Meshnet** in the left menu
3. Your mini PC should appear under **My devices** once it is
   registered -- if not, click **Refresh**
4. If the device does not appear automatically, go back to the mini PC
   terminal and check pending device requests:
   ```bash
   nordvpn meshnet peer list
   ```
   Approve a device with:
   ```bash
   nordvpn meshnet peer allow <device-name>
   ```

### 2.4 Test Remote Access

From another device with Meshnet enabled, try pinging the mini PC
using its Meshnet IP (from step 2.2):

```powershell
ping 100.64.x.x
```

If you get a reply, remote access is working. You can now reach every
service on the mini PC at `http://100.64.x.x:<port>` from any device
on your Meshnet, without opening any ports on your router.

> **Note:** Meshnet and regular NordVPN tunnelling work independently.
> You can have NordVPN connected for general browsing on a device and
> still use Meshnet to reach your homelab at the same time.

---

## 3. Generating Secrets

Before filling in environment files, generate the values that cannot
simply be typed in.

### 3.1 Grafana Admin Password

Pick a strong password. No generation step required -- just choose one
and note it down.

### 3.2 Tailscale Auth Key

Tailscale runs as a container in the infrastructure-networking stack and
provides a backup remote access method alongside Meshnet.

1. Go to `https://login.tailscale.com/admin/settings/keys` in your
   browser
2. Click **Generate auth key**
3. Configure it:
   - **Reusable:** No (you only need to register this one host)
   - **Expiry:** Set to 90 days or longer
4. Click **Generate key** and copy the result immediately -- it starts
   with `tskey-auth-` and will not be shown again after you close the
   dialog

### 3.3 Authentik Secret Key

This is a cryptographic key that Authentik uses to sign all sessions
and tokens. Run this command on the Linux host:

```bash
openssl rand -hex 32
```

`openssl` is a standard cryptography tool available on Linux. This
command generates 32 random bytes and prints them as a 64-character hex
string. Copy the output -- treat it like a password and store it safely.

### 3.4 ntfy Topic Name

ntfy uses named topics for notifications -- like a Slack channel name.
You subscribe to a topic on your phone and any service that posts to
that topic sends you a notification.

Choose a name for your Watchtower notification topic (e.g.
`watchtower`, `homelab-alerts`). This is just a string you make up --
write it down, you will need it in the next section and again during
ntfy setup.

---

## 4. Updating Environment Files

### 4.1 dashboards-automation (new file)

This stack did not have an environment file in v1. Create one:

```bash
nano /opt/docker/stacks/dashboards-automation/.env
```

```
GRAFANA_PASSWORD=your-grafana-password
VLAN11_IP=192.168.11.10
```

Replace `192.168.11.10` with the actual IP you assigned to `eth0.11`
in the Netplan config.

Save and close (Ctrl+X, Y, Enter).

### 4.2 infrastructure-networking (add to existing)

Open the existing file:

```bash
nano /opt/docker/stacks/infrastructure-networking/.env
```

The file already has `PIHOLE_PASSWORD`. Add three new lines below it:

```
PIHOLE_PASSWORD=your-existing-pihole-password
TAILSCALE_AUTHKEY=tskey-auth-xxxxxxxxxxxx
WATCHTOWER_NTFY_TOPIC=watchtower
VLAN11_IP=192.168.11.10
```

Replace `tskey-auth-xxxxxxxxxxxx` with the key from step 3.2,
`watchtower` with the topic name from step 3.4, and `192.168.11.10`
with your actual VLAN 11 IP.

Save and close.

### 4.3 media-gaming (add to existing)

Open the existing file:

```bash
nano /opt/docker/stacks/media-gaming/.env
```

Add one line at the bottom:

```
DB_USERNAME=immich
DB_PASSWORD=your-existing-password
DB_DATABASE_NAME=immich
VLAN61_IP=192.168.61.10
```

`VLAN61_IP` must match the IP configured for `eth0.61` in the Netplan config. VLAN 61 is newly created -- before deploying this stack, open the Ubiquiti controller and add a fixed IP reservation for the mini PC's MAC address at `192.168.61.10` on VLAN 61, or confirm the DHCP range for VLAN 61 starts above `.10` so there is no conflict. Leave the existing DB credentials unchanged.

Save and close.

### 4.4 tools (new file)

Create the tools stack directory and its environment file:

```bash
mkdir -p /opt/docker/stacks/tools
nano /opt/docker/stacks/tools/.env
```

```
DB_USER=wikijs
DB_PASS=your-wikijs-db-password
DB_NAME=wikijs
VLAN11_IP=192.168.11.10
```

Save and close. Choose a unique password -- this is separate from the
auth stack's PostgreSQL instance.

### 4.5 dockge (new file)

Dockge did not previously need an environment file, but the v2 port
binding requires the VLAN 11 IP. Docker Compose automatically reads a
`.env` file in the same directory as the compose file, so no changes to
the compose file itself are needed -- just create the env file:

```bash
nano /opt/docker/stacks/dockge/.env
```

```
VLAN11_IP=192.168.11.10
```

Save and close.

### 4.6 auth (new file)

Create the auth stack directory and its environment file:

```bash
mkdir -p /opt/docker/stacks/auth
nano /opt/docker/stacks/auth/.env
```

```
PG_USER=authentik
PG_PASS=your-authentik-db-password
PG_DB=authentik
AUTHENTIK_SECRET_KEY=your-64-character-hex-string-from-step-3-3
VLAN11_IP=192.168.11.10
```

Save and close.

---

## 5. Copying Config Files to the Host

### 5.1 v2 Compose Files

Copy the v2 compose files from the repository to the host. From your
Windows machine:

```powershell
scp C:\path\to\repo\stacks\dashboards-automation\compose.v2.yaml username@192.168.11.10:/opt/docker/stacks/dashboards-automation/
scp C:\path\to\repo\stacks\infrastructure-networking\compose.v2.yaml username@192.168.11.10:/opt/docker/stacks/infrastructure-networking/
scp C:\path\to\repo\stacks\media-gaming\compose.v2.yaml username@192.168.11.10:/opt/docker/stacks/media-gaming/
scp C:\path\to\repo\stacks\auth\compose.yaml username@192.168.11.10:/opt/docker/stacks/auth/
scp C:\path\to\repo\stacks\tools\compose.yaml username@192.168.11.10:/opt/docker/stacks/tools/
```

### 5.2 Prometheus Configuration

Prometheus requires a `prometheus.yml` config file before it will
start. Without it the container exits immediately with an error.

Create the config directory and copy the file:

```bash
mkdir -p /opt/docker/stacks/dashboards-automation/prometheus/config
```

From your Windows machine:

```powershell
scp C:\path\to\repo\stacks\dashboards-automation\prometheus\prometheus.yml username@192.168.11.10:/opt/docker/stacks/dashboards-automation/prometheus/config/
```

Confirm it arrived:

```bash
cat /opt/docker/stacks/dashboards-automation/prometheus/config/prometheus.yml
```

You should see the scrape configuration with jobs for `prometheus` and
`node-exporter`.

---

## 6. Migrating Existing Stacks to v2

For each stack, you will stop it, then start it again using the v2
compose file. The process is the same for each stack.

> **Data is preserved.** Docker volumes (databases, config files, caches)
> are stored on disk and are not affected by stopping a container or
> switching to a different compose file. The migration adds new services;
> it does not remove or reset existing ones.

### 6.1 dashboards-automation

```bash
cd /opt/docker/stacks/dashboards-automation
docker compose down
docker compose -f compose.v2.yaml up -d
```

Verify all containers started:

```bash
docker compose -f compose.v2.yaml ps
```

All services should show `running`. Check that existing services still
work before proceeding: Homepage at `http://192.168.11.10:3000`, Home
Assistant at `http://192.168.11.10:8123`.

### 6.2 dockge

No v2 file -- this stack is unchanged. No action needed.

### 6.3 infrastructure-networking

```bash
cd /opt/docker/stacks/infrastructure-networking
docker compose down
docker compose -f compose.v2.yaml up -d
```

Verify:

```bash
docker compose -f compose.v2.yaml ps
```

Check that Pi-hole and Nginx Proxy Manager are still running:
`http://192.168.11.10:8080` and `http://192.168.11.10:81`.

To confirm Tailscale registered, check its logs:

```bash
docker logs tailscale | grep -i "logged in\|authenticated\|running"
```

If Tailscale does not register, the most common cause is an already-
used auth key. Generate a new one (step 3.2) and update the `.env`
file, then restart the container:

```bash
docker compose -f compose.v2.yaml restart tailscale
```

### 6.4 media-gaming

```bash
cd /opt/docker/stacks/media-gaming
docker compose down
docker compose -f compose.v2.yaml up -d
```

Immich will take 30-60 seconds to restart as the database and Redis
go through their health checks. Jellyfin will be available immediately.

Watch Immich come back up:

```bash
docker compose -f compose.v2.yaml logs -f immich-server
```

Wait for `Immich Server is listening on` before proceeding.

---

## 7. Deploying the Auth Stack

The `auth` stack is entirely new. There is no migration from a previous
state.

```bash
cd /opt/docker/stacks/auth
docker compose up -d
```

Watch the startup logs to confirm Postgres and Redis become healthy
before Authentik starts:

```bash
docker compose logs -f
```

You are looking for log lines from `authentik_server` that say
`Starting server` or `Listening on`. This typically takes 60-90 seconds
on first start while Authentik runs its database migrations.

Press **Ctrl+C** to stop following the logs once you see Authentik is
running.

---

## 8. Deploying the Tools Stack

The `tools` stack is also new -- there is no migration from a previous
state.

```bash
cd /opt/docker/stacks/tools
docker compose up -d
```

WikiJS waits for Postgres to pass its health check before starting,
the same pattern as the auth and media-gaming stacks. Watch the logs:

```bash
docker compose logs -f wikijs
```

WikiJS is ready when you see a line containing `HTTP Server started`.
This typically takes 20-30 seconds.

---

## 9. First-Time Service Setup

### 9.1 Uptime Kuma

1. Open `http://192.168.11.10:3001`
2. Create an admin account on the first-visit screen
3. Add a monitor for each service -- click **+ Add Monitor**:
   - **Monitor type:** HTTP(s)
   - **Friendly name:** Service name (e.g. Immich)
   - **URL:** `http://localhost:<port>` (from the host's perspective)
4. Suggested monitors to add:

| Name | URL |
|------|-----|
| Homepage | `http://localhost:3000` |
| Home Assistant | `http://localhost:8123` |
| Grafana | `http://localhost:3002` |
| Pi-hole | `http://localhost:8080` |
| Nginx Proxy Manager | `http://localhost:81` |
| Immich | `http://localhost:2283` |
| Jellyfin | `http://localhost:8096` |
| Authentik | `http://localhost:9000` |
| ntfy | `http://localhost:8082` |

### 9.2 Grafana

1. Open `http://192.168.11.10:3002`
2. Log in with username `admin` and the `GRAFANA_PASSWORD` from step 3.1
3. Add Prometheus as a data source:
   - Go to **Connections > Data sources > Add data source**
   - Select **Prometheus**
   - Set the URL to `http://prometheus:9090`
     (Grafana and Prometheus are on the same Docker network, so use the
     container name rather than the host IP)
   - Click **Save & test** -- you should see "Data source is working"
4. Import a pre-built dashboard for system metrics:
   - Go to **Dashboards > New > Import**
   - Enter `1860` in the **Import via grafana.com** field
   - Click **Load**
   - Select your Prometheus data source from the dropdown
   - Click **Import**
   - The Node Exporter Full dashboard will appear, showing CPU, memory,
     disk, and network metrics for the host

### 9.3 ntfy

ntfy is a push notification server. You subscribe to a topic on your
phone and services post to that topic when they have something to
report.

1. Open `http://192.168.11.10:8082`
2. No account creation is needed for basic use
3. Install the **ntfy** app on your phone (available on iOS and Android)
4. In the app, add your server:
   - Tap **+** or **Add subscription**
   - Set the server URL to `http://<meshnet-ip>:8082` (use the Meshnet
     IP from step 2.2 so it works when you are away from home)
   - Set the topic name to whatever you entered in `WATCHTOWER_NTFY_TOPIC`
     (e.g. `watchtower`)
   - Subscribe

To confirm Watchtower notifications are wired up correctly, trigger a
test report:

```bash
docker exec watchtower /watchtower --run-once --notification-report
```

You should receive a push notification on your phone within a few
seconds. If nothing arrives, double-check the `WATCHTOWER_NTFY_TOPIC`
in the `.env` file and confirm the ntfy container is running.

### 9.4 Jellyfin

1. Open `http://192.168.61.10:8096`
2. The first-launch wizard will ask for:
   - A preferred display language
   - A username and password for the Jellyfin admin account
   - A media library -- click **Add Media Library**:
     - **Content type:** Movies, TV Shows, or Music depending on your
       library
     - **Folders:** Click the `+` button and navigate to `/media`
       (this is the container path for `/mnt/synology/media`)
   - Complete the wizard and let the library scan run
3. Enable Intel Quick Sync hardware acceleration:
   - Go to **Admin Dashboard** (hamburger menu > Administration)
   - Click **Playback** in the left menu
   - Set **Hardware acceleration** to **Intel QuickSync (QSV)**
   - Check the hardware decoding boxes for the video formats you use
     (H.264 and H.265 are the most common)
   - Click **Save**
   - Restart the Jellyfin container to apply:
     ```bash
     docker restart jellyfin
     ```

### 9.5 Authentik

**Initial admin setup:**

1. Open `http://192.168.11.10:9000/if/flow/initial-setup/`
   Note the `/if/flow/initial-setup/` path -- the plain root URL
   redirects elsewhere on a fresh install
2. Enter an email address and password for the Authentik admin account
3. Click **Continue**
4. You will be taken to the Authentik user home page

**Access the admin panel:**

- Go to `http://192.168.11.10:9000/if/admin/`
- This is the management interface where you configure applications,
  providers, and users

**Connecting Authentik to Nginx Proxy Manager** (forward authentication):

This is an optional but recommended step that puts an Authentik login
screen in front of any service you proxy through NPM. The full
procedure is in the Authentik documentation at:

`https://docs.goauthentik.io/docs/add-secure-apps/providers/proxy/`

The short version:
1. In Authentik: create a **Proxy Provider** for each service you want
   to protect
2. In NPM: add a custom location block to the relevant proxy host that
   forwards authentication checks to Authentik
3. Users visiting the service will be redirected to an Authentik login
   page before being passed through to the service

### 9.6 Tailscale

1. Open `https://login.tailscale.com/admin/machines` in your browser
2. The mini PC should appear in the machines list with a Tailscale IP
   in the `100.x.x.x` range
3. Advertise your local subnets so remote devices can reach everything
   on the network -- including the NAS and the `media-gaming` stack's
   services, both reachable via VLAN 61:
   ```bash
   docker exec tailscale tailscale up --advertise-routes=192.168.11.0/24,192.168.61.0/24
   ```
   Replace the subnets with your actual VLAN 11 and VLAN 61 CIDRs.
4. Back in the Tailscale admin panel, find the mini PC in the machines
   list, click the three-dot menu, select **Edit route settings**, and
   approve the advertised routes
5. From any Tailscale-connected device, you can now reach all homelab
   services and local network devices at their LAN IPs -- no port
   forwarding required

**Pi-hole DNS for all VLANs:**

Configure the Ubiquiti DHCP server for each VLAN to hand out the mini
PC's VLAN 11 IP as the DNS server. In the Ubiquiti controller:

1. Go to **Settings > Networks**
2. For each VLAN (11, 20, 30, 31, 40, 50, 60, 61) -- see
   [`guides/networking/vlan-reference.md`](../networking/vlan-reference.md)
   for the full list:
   - Click the VLAN to edit it
   - Under **DHCP**, set **DNS Server 1** to `192.168.11.10` (your
     VLAN 11 IP)
   - Save

Clients on every VLAN will now use Pi-hole for DNS automatically via
DHCP, with no manual configuration per device.

### 9.7 WikiJS

**Initial admin setup:**

1. Open `http://192.168.11.10:3003`
2. The first-launch screen asks for:
   - Administrator email address
   - Administrator password
   - Site name (e.g. `Homelab Wiki`)
3. Click **Install** -- WikiJS will run its database setup. This takes
   30-60 seconds. Do not close the browser tab.
4. After setup completes you will be taken to the wiki home page

**Create your first page:**

1. Click **New Page** (top right)
2. Choose **Markdown** as the editor
3. Set a title and path (e.g. title `Home`, path `/home`)
4. Write your content and click **Save**

**Connect WikiJS to Authentik for single sign-on (optional):**

This lets users log in to WikiJS using their Authentik account instead
of a separate WikiJS password. It requires Authentik to be set up first
(section 8.5).

In Authentik:
1. Go to the admin panel at `http://192.168.11.10:9000/if/admin/`
2. Navigate to **Applications > Providers > Create**
3. Choose **OAuth2/OpenID Provider**
4. Set a name (e.g. `WikiJS`) and note the **Client ID** and
   **Client Secret** that are generated
5. Set the **Redirect URIs** to:
   `http://192.168.11.10:3003/login/3a11e8f6-0450-4b42-ba78-a34ee05e75e4/callback`
   (the GUID is WikiJS's fixed ID for the generic OpenID Connect strategy)

In WikiJS:
1. Go to **Administration** (left menu, gear icon)
2. Navigate to **Authentication**
3. Click **Add Strategy** and select **Generic OpenID Connect**
4. Fill in:
   - **Client ID:** from Authentik
   - **Client Secret:** from Authentik
   - **Authorization Endpoint:** `http://192.168.11.10:9000/application/o/<app-slug>/authorize/`
   - **Token Endpoint:** `http://192.168.11.10:9000/application/o/token/`
   - **User Info Endpoint:** `http://192.168.11.10:9000/application/o/userinfo/`
5. Enable the strategy and save

Users can now log in to WikiJS via the Authentik login page.

**Add WikiJS to Uptime Kuma:**

In Uptime Kuma, add a new HTTP monitor:
- **Name:** WikiJS
- **URL:** `http://localhost:3003`

---

## 10. Verification Checklist

Run through this table after completing all setup. Every item should
pass before considering the v2 migration complete.

| Item | How to Verify |
|------|--------------|
| All v2 containers running | `docker ps` -- no `Exiting` or `Restarting` states |
| Homepage still works | `http://192.168.11.10:3000` |
| Home Assistant still works | `http://192.168.11.10:8123` |
| Pi-hole still resolving DNS | `nslookup google.com 192.168.11.10` from Windows returns an IP |
| Immich still loads | `http://192.168.61.10:2283` |
| Uptime Kuma loads, monitors added | `http://192.168.11.10:3001` |
| Grafana loads, Prometheus data source connected | `http://192.168.11.10:3002` -- Node Exporter dashboard shows data |
| Prometheus loads, scraping targets | `http://192.168.11.10:9090` > Status > Targets -- both targets show `UP` |
| ntfy loads | `http://192.168.11.10:8082` |
| Watchtower notification received in ntfy app | Run test command from step 9.3 |
| Jellyfin loads, media visible | `http://192.168.61.10:8096` -- library scan complete |
| Jellyfin hardware transcoding active | Attempt playback, check Admin Dashboard > Dashboard for active transcoding sessions |
| Authentik admin panel loads | `http://192.168.11.10:9000/if/admin/` |
| Tailscale registered | Machine visible at `login.tailscale.com/admin/machines` |
| NordVPN Meshnet active | `nordvpn meshnet status` on host shows enabled |
| Remote access over Meshnet works | Browse to `http://<meshnet-ip>:3000` from a device not on your home network |
| WikiJS loads | `http://192.168.11.10:3003` |
| WikiJS Postgres healthy | `docker inspect wikijs_postgres --format '{{.State.Health.Status}}'` returns `healthy` |

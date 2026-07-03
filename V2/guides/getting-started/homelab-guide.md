# Homelab Setup Guide

This guide covers the complete deployment and initial configuration of
the homelab: `dashboards-automation`, `dockge`, `infrastructure-networking`,
`media-gaming`, `auth`, and `tools`. It assumes you are comfortable
with general Windows IT concepts (networking, DNS, services, ports,
credentials) but may be new to Linux and the command line.

Deep-dive setup for Nginx Proxy Manager and Pi-hole lives in their own
guides under [Networking](../README.md#networking) -- this guide gets
them running with default credentials and points there for the full
reverse-proxy and DNS configuration. Deep-dive setup for services added
on top of the base stacks (pgAdmin, Stirling PDF, Mealie, n8n, IT
Tools, Actual Budget, Paperless-ngx, Grocy, Linkwarden, Backrest in
`tools`;
Audiobookshelf and Kavita in `media-gaming`; Loki and Promtail in
`dashboards-automation`; CrowdSec in `infrastructure-networking`) lives
in that stack's guide under [Stacks](../README.md#stacks). The `llm`
stack is optional and entirely separate -- see
[llm-stack-guide.md](../stacks/llm-stack-guide.md).

If you are re-deploying an existing host rather than starting from
scratch, skip to the relevant section.

---

## Contents

1. [Working on Linux from Windows](#1-working-on-linux-from-windows)
2. [Prerequisites](#2-prerequisites)
3. [Remote Access: NordVPN Meshnet](#3-remote-access-nordvpn-meshnet)
4. [Generating Secrets](#4-generating-secrets)
5. [Environment Files](#5-environment-files)
6. [Copying Config Files to the Host](#6-copying-config-files-to-the-host)
7. [Deploying the Stacks](#7-deploying-the-stacks)
8. [First-Time Service Setup](#8-first-time-service-setup)
9. [Verification Checklist](#9-verification-checklist)

---

## 1. Working on Linux from Windows

### Connecting to the Host

All commands in this guide are run over SSH from your Windows machine.
Open **Windows Terminal** (or PowerShell) and connect:

```powershell
ssh username@192.168.11.10
```

Replace `username` with the account you created during the Linux
installation. If you have not set up SSH key authentication, you will
be prompted for a password.

If you do not have Windows Terminal, download it from the Microsoft
Store, or use **PuTTY** as an alternative.

### Quick Linux Reference

These are the Linux equivalents of things you already know from Windows.

| Windows | Linux equivalent | Notes |
|---------|-----------------|-------|
| Run as Administrator | `sudo` | Prefix any command with `sudo` to run it as root. You will be prompted for your password. |
| Notepad (edit a file) | `nano filename` | Terminal-based text editor. See below. |
| File Explorer path `C:\folder\file` | `/folder/file` | Paths use forward slashes. Case-sensitive. |
| `dir` | `ls` | Lists files in a directory. |
| `type filename` | `cat filename` | Prints a file's contents to the terminal. |
| Services (services.msc) | `systemctl` | Manages background services. |
| Task Manager processes | `docker ps` | Lists running containers. |

### Using the nano Text Editor

`nano` is the simplest terminal text editor on Linux. You will use it
to create and edit the `.env` configuration files.

To create or open a file:
```bash
nano /path/to/filename
```

- Type or paste your content normally.
- To save: press **Ctrl+X**, then **Y** when asked "Save modified
  buffer?", then **Enter** to confirm the filename.
- To discard changes and exit: press **Ctrl+X**, then **N**.

The shortcuts shown at the bottom of the nano screen use `^` to mean
**Ctrl** (e.g. `^X` means Ctrl+X).

### A Note on File Paths

Linux paths are case-sensitive. `/opt/docker/stacks` and
`/opt/Docker/Stacks` are different locations. Copy paths exactly as
written in this guide.

---

## 2. Prerequisites

### 2.1 Disable systemd-resolved

Pi-hole needs exclusive access to port 53 (DNS). On Ubuntu and Debian,
a background service called `systemd-resolved` occupies that port by
default -- similar to how a Windows service can hold a port open.

Check whether it is running:

```bash
sudo systemctl is-active systemd-resolved
```

If the output is `active`, stop and disable it:

```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

Verify port 53 is now free:

```bash
sudo ss -tulnp | grep :53
```

The output should be empty. If anything is still listed, find and stop
that process before continuing.

### 2.2 Mount the Base NAS Shares

Immich stores uploaded photos on the Synology NAS and Jellyfin serves
its media library from there too. Both NFS shares must be mounted on
the host before starting the `media-gaming` stack, or the containers
will create a local directory instead of writing to the NAS.

Check whether the mounts are present:

```bash
ls /mnt/synology/immich
ls /mnt/synology/media
```

If a path does not exist, add the NFS share to `/etc/fstab` (the Linux
equivalent of persistent drive mappings) and mount it.

Open fstab:
```bash
sudo nano /etc/fstab
```

Add two lines at the bottom in this format -- one for Immich's
uploads, one for Jellyfin's media library:
```
<nas-ip>:/volume1/immich   /mnt/synology/immich   nfs   defaults   0 0
<nas-ip>:/volume1/media    /mnt/synology/media    nfs   defaults   0 0
```

Replace `<nas-ip>` with your Synology's IP and the `/volume1/...`
paths with your actual shared folder paths. Save the file (Ctrl+X, Y,
Enter). A complete reference copy of this file is at
[`config/fstab`](../../config/fstab).

Create the mount point and mount everything:
```bash
sudo mkdir -p /mnt/synology/immich
sudo mkdir -p /mnt/synology/media
sudo mount -a
```

Confirm the mount is active:
```bash
df -h | grep synology
```

You should see a line showing the NAS share and its available space.

> Audiobookshelf, Kavita, and Backrest need additional NAS shares of
> their own. Those are covered in
> [media-gaming-guide.md](../stacks/media-gaming-guide.md) and
> [tools-guide.md](../stacks/tools-guide.md) respectively -- mount them
> when you get to those sections, not here.

### 2.3 Confirm Intel Quick Sync

Immich and Jellyfin both use the host GPU for hardware-accelerated
transcoding and thumbnail generation. Check the device is accessible:

```bash
ls /dev/dri
```

You should see `card0` and `renderD128`. If the directory is missing or
empty, install the Intel GPU drivers:

```bash
sudo apt update
sudo apt install intel-gpu-tools
sudo modprobe i915
```

### 2.4 Create the Stacks Directory

Dockge manages stacks from a single directory on the host. Create it
and give your user account ownership (so you do not need `sudo` for
every file operation inside it):

```bash
sudo mkdir -p /opt/docker/stacks
sudo chown $USER:$USER /opt/docker/stacks
```

`$USER` is a built-in variable -- Linux fills in your username
automatically. You do not need to replace it.

### 2.5 Configure the Trunk Port and VLAN Sub-Interfaces

The mini PC needs a trunk uplink from the Ubiquiti switch so it can
have a presence on multiple VLANs simultaneously. This must be
configured in two places: on the Ubiquiti switch port, and on the Linux
host. See
[`guides/networking/vlan-reference.md`](../networking/vlan-reference.md)
for the complete VLAN plan -- this section only configures the two
VLANs the mini PC needs a direct interface on.

**On the Ubiquiti switch:**

1. Log in to your Ubiquiti controller
2. Navigate to **Devices > [your switch] > Ports**
3. Find the port connected to the mini PC
4. Change the port profile from an access port (single VLAN) to a trunk:
   - Set **Native Network** to VLAN 11 (Services) -- this is the
     untagged VLAN the host uses as its primary network
   - Under **Tagged Networks**, add VLAN 61 (NAS) -- the
     `media-gaming` stack binds here for same-subnet NFS access to
     the NAS, which also lives on this VLAN
   - Apply the change

**On the Linux host (Netplan):**

Ubuntu uses Netplan to manage network configuration. Find the existing
config file:

```bash
ls /etc/netplan/
```

You will see a file named something like `00-installer-config.yaml` or
`01-netcfg.yaml`. Open it:

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

Replace the contents with the following, adjusting `enp171s0` to match
your actual network interface name (check with `ip link show`) and
replacing the IP addresses with your actual VLAN subnet addresses.
VLAN 11 is untagged/native on this switch port, so it's configured
directly on the physical interface rather than as a tagged VLAN
sub-interface; VLAN 61 is tagged, so it gets its own `vlans:` entry:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp171s0:
      dhcp4: false
      addresses:
        - 192.168.11.10/24
      routes:
        - to: default
          via: 192.168.11.1
      nameservers:
        addresses: [127.0.0.1]
  vlans:
    vlan61:
      id: 61
      link: enp171s0
      addresses:
        - 192.168.61.10/24
```

> **VLAN 61 IP reservation:** `192.168.61.10` is the suggested static IP for the mini PC on VLAN 61. VLAN 61 is newly created and has no existing devices. Before running `netplan apply`, open the Ubiquiti controller and add a fixed IP reservation for the mini PC's MAC address at `192.168.61.10` on VLAN 61, or confirm your DHCP pool for VLAN 61 starts above `.10`. Ubiquiti creates the VLAN gateway (`192.168.61.1`) automatically when the VLAN is configured.

> **Important:** The `nameservers` entry on `enp171s0` points to
> `127.0.0.1`. This is intentional -- once Pi-hole is running, the
> host itself will use it for DNS. Leave this as-is.

A complete reference copy of this file is at
[`config/netplan-00-installer-config.yaml`](../../config/netplan-00-installer-config.yaml).

Save and close. Apply the configuration:

```bash
sudo netplan apply
```

> **Warning:** If you are connected over SSH, your session will
> disconnect briefly when the network reconfigures. Reconnect using the
> VLAN 11 IP (`192.168.11.10` in the example above).

Verify both interfaces are up:

```bash
ip addr show enp171s0
ip addr show vlan61
```

Each should show its assigned IP address and `state UP`.

**Find your network interface name:**

If `enp171s0` does not exist on your system, find the correct name with:

```bash
ip link show
```

Common names are `eth0`, `ens18`, `enp3s0`, `enp0s3`, or `enp171s0`.
Replace `enp171s0` everywhere in the Netplan config with whatever name
you see.

### 2.6 Copy Compose Files to the Host

Each stack directory needs its `compose.yaml` file. Copy them from the
repository to the host. From your Windows machine:

```powershell
scp -r C:\path\to\repo\stacks\* username@192.168.11.10:/opt/docker/stacks/
```

Or, if you have the repository cloned on the Linux host already:

```bash
cp -r /path/to/repo/stacks/* /opt/docker/stacks/
```

Confirm the structure looks right:

```bash
ls /opt/docker/stacks
```

You should see six directories: `dashboards-automation`, `dockge`,
`infrastructure-networking`, `media-gaming`, `auth`, `tools`.

---

## 3. Remote Access: NordVPN Meshnet

Meshnet is a feature of your existing NordVPN subscription that lets
your devices connect directly to each other without port forwarding.
Think of it like a VPN that you run for your own devices rather than
routing through NordVPN's servers. This is how you will access the
homelab remotely, alongside Tailscale (deployed as part of
`infrastructure-networking` below) as a second, independent path.

This is set up on the host itself, outside Docker.

### 3.1 Install NordVPN on the Mini PC Host

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

### 3.2 Enable Meshnet on the Host

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

### 3.3 Enable Meshnet on Your Other Devices

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

### 3.4 Test Remote Access

From another device with Meshnet enabled, try pinging the mini PC
using its Meshnet IP (from step 3.2):

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

## 4. Generating Secrets

Before filling in environment files, generate the values that cannot
simply be typed in.

### 4.1 Grafana Admin Password

Pick a strong password. No generation step required -- just choose one
and note it down.

### 4.2 Tailscale Auth Key

Tailscale runs as a container in the `infrastructure-networking` stack
and provides a second remote access method alongside Meshnet.

1. Go to `https://login.tailscale.com/admin/settings/keys` in your
   browser
2. Click **Generate auth key**
3. Configure it:
   - **Reusable:** No (you only need to register this one host)
   - **Expiry:** Set to 90 days or longer
4. Click **Generate key** and copy the result immediately -- it starts
   with `tskey-auth-` and will not be shown again after you close the
   dialog

### 4.3 Authentik Secret Key

This is a cryptographic key that Authentik uses to sign all sessions
and tokens. Run this command on the Linux host:

```bash
openssl rand -hex 32
```

`openssl` is a standard cryptography tool available on Linux. This
command generates 32 random bytes and prints them as a 64-character hex
string. Copy the output -- treat it like a password and store it safely.

### 4.4 ntfy Topic Name

ntfy uses named topics for notifications -- like a Slack channel name.
You subscribe to a topic on your phone and any service that posts to
that topic sends you a notification.

Choose a name for your Watchtower notification topic (e.g.
`watchtower`, `homelab-alerts`). This is just a string you make up --
write it down, you will need it in the next section and again during
ntfy setup.

### 4.5 Database Passwords

Pick strong, unique passwords for the Immich (`media-gaming`), WikiJS
(`tools`), and Authentik (`auth`) PostgreSQL instances. Each stack's
database is isolated from the others -- reusing a password across
stacks is not required and not recommended.

---

## 5. Environment Files

Six stacks need a `.env` file before they will start. These files hold
sensitive values (passwords, credentials) and are intentionally not
stored in the repository -- similar to how you would not commit a
`web.config` with connection strings to source control.

### 5.1 dashboards-automation

```bash
nano /opt/docker/stacks/dashboards-automation/.env
```

```text
GRAFANA_PASSWORD=your-grafana-password
VLAN11_IP=192.168.11.10
```

Replace `192.168.11.10` with the actual IP you assigned to `enp171s0`
in the Netplan config.

### 5.2 dockge

```bash
nano /opt/docker/stacks/dockge/.env
```

```text
VLAN11_IP=192.168.11.10
```

### 5.3 infrastructure-networking

```bash
nano /opt/docker/stacks/infrastructure-networking/.env
```

```text
PIHOLE_PASSWORD=your-pihole-admin-password
TAILSCALE_AUTHKEY=tskey-auth-xxxxxxxxxxxx
WATCHTOWER_NTFY_TOPIC=watchtower
VLAN11_IP=192.168.11.10
```

Replace `tskey-auth-xxxxxxxxxxxx` with the key from step 4.2 and
`watchtower` with the topic name from step 4.4.

### 5.4 media-gaming

```bash
nano /opt/docker/stacks/media-gaming/.env
```

```text
DB_USERNAME=immich
DB_PASSWORD=your-database-password
DB_DATABASE_NAME=immich
VLAN61_IP=192.168.61.10
```

`VLAN61_IP` must match the IP configured for `vlan61` in the Netplan
config.

> **Important:** Set `DB_PASSWORD` before you start the stack for the
> first time and do not change it afterwards. This password initialises
> the PostgreSQL database. If you change it after the database exists,
> Immich will fail to connect and you will need to reset the database.

### 5.5 auth

```bash
mkdir -p /opt/docker/stacks/auth
nano /opt/docker/stacks/auth/.env
```

```text
PG_USER=authentik
PG_PASS=your-authentik-db-password
PG_DB=authentik
AUTHENTIK_SECRET_KEY=your-64-character-hex-string-from-step-4-3
VLAN11_IP=192.168.11.10
```

### 5.6 tools

```bash
mkdir -p /opt/docker/stacks/tools
nano /opt/docker/stacks/tools/.env
```

```text
DB_USER=wikijs
DB_PASS=your-wikijs-db-password
DB_NAME=wikijs
VLAN11_IP=192.168.11.10
```

Choose a unique password -- this is separate from the `auth` stack's
PostgreSQL instance. [tools-guide.md](../stacks/tools-guide.md) adds
further `.env` entries for pgAdmin, n8n, Paperless-ngx, and Linkwarden
when you deploy those services.

---

## 6. Copying Config Files to the Host

### 6.1 Prometheus Configuration

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

> Loki and Promtail need their own config files, copied when you
> deploy them -- see
> [dashboards-automation-guide.md](../stacks/dashboards-automation-guide.md).

---

## 7. Deploying the Stacks

### Order Matters

`dashboards-automation` must be deployed first. It creates a Docker
network called `proxy_net` that every other stack connects to. Think of
it like a virtual switch that the other containers plug in to -- if
`dashboards-automation` is not running, the other stacks cannot start.
`dockge` is the only stack that does not join `proxy_net` and can be
deployed at any point.

1. `dashboards-automation`
2. `dockge`
3. `infrastructure-networking`
4. `media-gaming`
5. `auth`
6. `tools`

### 7.1 dashboards-automation

```bash
cd /opt/docker/stacks/dashboards-automation
docker compose up -d
```

The `-d` flag means "detached" -- the containers run in the background,
similar to starting a Windows service. Without it, the output streams
to your terminal and stops when you close the SSH session.

Confirm the `proxy_net` network was created:

```bash
docker network ls | grep proxy_net
```

You should see one line with `proxy_net` and `bridge` in it. If the
output is empty, check the logs:

```bash
docker compose logs
```

### 7.2 dockge

```bash
cd /opt/docker/stacks/dockge
docker compose up -d
```

### 7.3 infrastructure-networking

```bash
cd /opt/docker/stacks/infrastructure-networking
docker compose up -d
```

Pi-hole takes 20-30 seconds to initialise on first start. Confirm all
containers are running:

```bash
docker compose ps
```

The `STATUS` column should show `running` for every container. If one
shows `exiting` or `restarting`, check its logs:

```bash
docker compose logs <service_name>
```

CrowdSec mounts NPM logs from `./npm/logs`, so it stays idle until NPM
has generated at least one access log entry -- this is expected and not
a failure. Its full setup, including enrolling with the CrowdSec Hub
and installing the host firewall bouncer, is in
[infrastructure-networking-guide.md](../stacks/infrastructure-networking-guide.md).

### 7.4 media-gaming

```bash
cd /opt/docker/stacks/media-gaming
docker compose up -d
```

`immich-server` will not start until Postgres and Redis pass their
health checks. This is by design -- it prevents Immich from trying to
connect before the database is ready, similar to a service dependency
in Windows. On a fresh deployment, expect to wait 30-60 seconds.

Watch the startup sequence in real time:

```bash
docker compose logs -f immich-server
```

The `-f` flag streams new log lines as they appear, like `tail -f` on
Windows. Press **Ctrl+C** to stop following the logs -- this does not
stop the container.

You are ready to proceed when you see:
```
Immich Server is listening on...
```

`immich-machine-learning` will download its AI models on first start.
This requires outbound internet access and can take several minutes.
The models are saved to `./immich/model-cache` and will not be
downloaded again after that.

Jellyfin will be available immediately once the stack is up.
Audiobookshelf and Kavita are separate additions covered in
[media-gaming-guide.md](../stacks/media-gaming-guide.md).

### 7.5 auth

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

### 7.6 tools

```bash
cd /opt/docker/stacks/tools
docker compose up -d
```

WikiJS waits for Postgres to pass its health check before starting,
the same pattern as `auth` and `media-gaming`. Watch the logs:

```bash
docker compose logs -f wikijs
```

WikiJS is ready when you see a line containing `HTTP Server started`.
This typically takes 20-30 seconds.

`tools` ships with many more services than WikiJS -- pgAdmin, Stirling
PDF, Mealie, n8n, IT Tools, Actual Budget, Paperless-ngx, Grocy,
Linkwarden, and Backrest. Their `.env` entries, NPM proxy hosts, and
first-time setup are covered in [tools-guide.md](../stacks/tools-guide.md).

---

## 8. First-Time Service Setup

### 8.1 Dockge

1. Open `http://192.168.11.10:5001` in your browser
2. The first-launch screen asks you to create an admin username and
   password -- do this immediately
3. After logging in, you should see every deployed stack listed. Green
   means all containers in that stack are running.

### 8.2 Nginx Proxy Manager and Pi-hole

> **Do this immediately after deployment.** NPM ships with a known
> default password (`admin@example.com` / `changeme`) and is
> accessible to anyone on your network.

Log in at `http://192.168.11.10:81` and change the credentials
immediately when prompted. Full NPM configuration (Cloudflare DNS,
Let's Encrypt wildcard certificate, every proxy host) is in
[nginx-proxy-manager-guide.md](../networking/nginx-proxy-manager-guide.md).

Pi-hole's web admin loads at `http://192.168.11.10:8080/admin` using
the `PIHOLE_PASSWORD` from your `.env` file. Full Pi-hole configuration
(network-wide DNS handoff, local records, blocklists, backup) is in
[pihole-guide.md](../networking/pihole-guide.md).

### 8.3 Home Assistant

1. Open `http://192.168.11.10:8123`
2. The first-launch wizard guides you through:
   - Creating a user account (this is the HA admin, separate from the
     Linux user)
   - Setting your home location (used for sunrise/sunset automations)
   - Choosing which device types to auto-discover on the network
3. After setup, check the **Notifications** panel (bell icon) for
   detected integrations -- HA will likely have already found devices
   on your network

### 8.4 Homepage

Homepage is configured through YAML files rather than a web UI. Unlike
the other services in this stack, its config is not created blank on
first start -- a full dashboard config for every service in this repo
is already checked in at
[`V2/stacks/dashboards-automation/homepage/config/`](../../stacks/dashboards-automation/homepage/config/),
which lands on the host at
`/opt/docker/stacks/dashboards-automation/homepage/config/` once you've
pulled the repo (see
[`git-deployment-guide.md`](../operations/git-deployment-guide.md)).
The Docker socket mount (for live RUNNING/STOPPED status pills) and the
`HOMEPAGE_VAR_*` environment wiring for widget API keys are already in
`compose.yaml` -- nothing to add there.

Before starting the stack, finish the setup steps documented in
[`homepage/config/DEPLOY.md`](../../stacks/dashboards-automation/homepage/config/DEPLOY.md):

- Set your real latitude/longitude/timezone in `widgets.yaml` (it ships
  with placeholder DC-area coordinates)
- Add `HOMEPAGE_VAR_IMMICH_KEY`, `HOMEPAGE_VAR_JELLYFIN_KEY`, and
  `HOMEPAGE_VAR_PIHOLE_KEY` to `dashboards-automation/.env` for the
  live Immich/Jellyfin/Pi-hole widgets (or delete a service's `widget:`
  block to keep it as a plain link without live stats)
- Double check the `container:` names in `services.yaml` against your
  actual `container_name:` values -- they assume the names used
  elsewhere in this repo's compose files

Once running, Homepage reloads automatically when config files are
saved -- no container restart needed. Refresh your browser to see
changes. A full list of supported icons, widgets, and configuration
options is at `https://gethomepage.dev/configs/services/`.

### 8.5 Immich

1. Open `http://192.168.11.10:2283`
2. The first-launch screen prompts you to create an admin account
3. After logging in, go to **Administration > Jobs** and confirm:
   - Database shows as connected (green dot)
   - Machine learning shows as connected (green dot)
   - If machine learning shows red, it is still downloading models --
     wait a few minutes and refresh
4. Go to **Administration > Storage Template** to configure how Immich
   organises uploaded files into folders (e.g. by year/month)

**To enable hardware transcoding for video:**
- Go to **Administration > Video Transcoding Settings**
- Set **Hardware acceleration** to **VAAPI**
- Save

### 8.6 AMP

1. Open `http://192.168.11.10:8081`
2. The first-launch wizard creates the initial AMP admin account
3. After logging in, create a game server instance:
   - Click **Create Instance**
   - Select the game (e.g. **Minecraft Java Edition**)
   - Give it a name and configure the port (default Minecraft: `25565`,
     already mapped in the compose file)
   - Click **Create**
4. The instance appears on the AMP dashboard -- click it to start,
   stop, view the console, or adjust settings

> **Adding more game servers:** Each game server needs its own port. If
> you add a second server, add its port to the `ports` section in
> `compose.yaml` before starting AMP (e.g. `- "25566:25566"`). After
> editing the compose file, restart AMP:
> ```bash
> docker compose up -d
> ```

### 8.7 Uptime Kuma

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
| WikiJS | `http://localhost:3003` |

### 8.8 Grafana and Prometheus

1. Open `http://192.168.11.10:3002`
2. Log in with username `admin` and the `GRAFANA_PASSWORD` from step 4.1
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

Adding Loki as a second data source for logs is covered in
[dashboards-automation-guide.md](../stacks/dashboards-automation-guide.md).

### 8.9 ntfy

ntfy is a push notification server. You subscribe to a topic on your
phone and services post to that topic when they have something to
report.

1. Open `http://192.168.11.10:8082`
2. No account creation is needed for basic use
3. Install the **ntfy** app on your phone (available on iOS and Android)
4. In the app, add your server:
   - Tap **+** or **Add subscription**
   - Set the server URL to `http://<meshnet-ip>:8082` (use the Meshnet
     IP from step 3.2 so it works when you are away from home)
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

### 8.10 Jellyfin

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

### 8.11 Authentik

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

### 8.12 Tailscale

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

### 8.13 WikiJS

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
(section 8.11).

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

## 9. Verification Checklist

Work through this table after completing all setup steps. Every item
should pass before considering the deployment complete.

| Item | How to Verify |
|------|--------------|
| SSH access to host works | You completed this guide |
| proxy_net network exists | `docker network ls \| grep proxy_net` returns one result |
| All containers running | `docker ps` -- no containers showing `Exiting` or `Restarting` (CrowdSec is expected to sit idle until NPM has log entries) |
| Homepage loads | Browse to `http://192.168.11.10:3000` |
| Home Assistant loads | Browse to `http://192.168.11.10:8123` |
| Dockge loads, stacks visible | Browse to `http://192.168.11.10:5001` |
| Uptime Kuma loads, monitors added | Browse to `http://192.168.11.10:3001` |
| Grafana loads, Prometheus data source connected | `http://192.168.11.10:3002` -- Node Exporter dashboard shows data |
| Prometheus loads, scraping targets | `http://192.168.11.10:9090` > Status > Targets -- both targets show `UP` |
| NPM admin loads, password changed | Browse to `http://192.168.11.10:81` |
| Pi-hole web loads, login works | Browse to `http://192.168.11.10:8080` |
| Pi-hole resolving DNS | Run `nslookup google.com 192.168.11.10` from your Windows machine -- should return an IP |
| Watchtower running | `docker ps \| grep watchtower` shows `Up` |
| ntfy loads, test notification received | `http://192.168.11.10:8082`; run the test command from section 8.9 |
| NAS mounts present | `df -h \| grep synology` shows `immich` and `media` |
| Intel QS available | `ls /dev/dri` shows `card0` and `renderD128` |
| Immich loads | Browse to `http://192.168.61.10:2283` |
| Immich ML connected | Administration > Jobs shows machine learning green |
| Immich Postgres healthy | `docker inspect immich_postgres --format '{{.State.Health.Status}}'` returns `healthy` |
| Immich Redis healthy | `docker inspect immich_redis --format '{{.State.Health.Status}}'` returns `healthy` |
| Jellyfin loads, media visible | `http://192.168.61.10:8096` -- library scan complete |
| Jellyfin hardware transcoding active | Attempt playback, check Admin Dashboard > Dashboard for active transcoding sessions |
| AMP loads | Browse to `http://192.168.11.10:8081` |
| Authentik admin panel loads | `http://192.168.11.10:9000/if/admin/` |
| Tailscale registered | Machine visible at `login.tailscale.com/admin/machines` |
| NordVPN Meshnet active | `nordvpn meshnet status` on host shows enabled |
| Remote access over Meshnet works | Browse to `http://<meshnet-ip>:3000` from a device not on your home network |
| WikiJS loads | `http://192.168.11.10:3003` |
| WikiJS Postgres healthy | `docker inspect wikijs_postgres --format '{{.State.Health.Status}}'` returns `healthy` |

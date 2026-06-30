# Homelab v1 Configuration Guide

This guide covers the initial deployment and configuration of the v1
stacks. It assumes you are comfortable with Windows IT concepts
(networking, DNS, services, ports) but may be new to Linux and the
command line.

If you are setting up on a new host, follow every section in order. If
you are re-deploying an existing stack, skip to the relevant section.

---

## Contents

1. [Working on Linux from Windows](#1-working-on-linux-from-windows)
2. [Prerequisites](#2-prerequisites)
3. [Creating Environment Files](#3-creating-environment-files)
4. [Deploying Stacks](#4-deploying-stacks)
5. [First-Time Service Setup](#5-first-time-service-setup)
6. [Verification Checklist](#6-verification-checklist)

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

### 2.2 Confirm NFS Mounts

Immich stores uploaded photos on the Synology NAS. The NFS share must
be mounted on the host before starting the media-gaming stack, or
Immich will create a local directory instead of writing to the NAS.

Check whether the mount is present:

```bash
ls /mnt/synology/immich
```

If the path does not exist, you need to add the NFS share to
`/etc/fstab` (the Linux equivalent of persistent drive mappings) and
mount it.

Open fstab:
```bash
sudo nano /etc/fstab
```

Add a line at the bottom in this format:
```
<nas-ip>:/volume1/immich   /mnt/synology/immich   nfs   defaults   0 0
```

Replace `<nas-ip>` with your Synology's IP and `/volume1/immich` with
the actual shared folder path. Save the file (Ctrl+X, Y, Enter).

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

### 2.3 Confirm Intel Quick Sync

Immich uses the host GPU for thumbnail generation. Check the device is
accessible:

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
host.

**On the Ubiquiti switch:**

1. Log in to your Ubiquiti controller
2. Navigate to **Devices > [your switch] > Ports**
3. Find the port connected to the mini PC
4. Change the port profile from an access port (single VLAN) to a trunk:
   - Set **Native Network** to VLAN 11 (Services) -- this is the
     untagged VLAN the host uses as its primary network
   - Under **Tagged Networks**, add VLAN 61 (Media)
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

Replace the contents with the following, adjusting `eth0` to match your
actual network interface name (check with `ip link show`) and replacing
the IP addresses with your actual VLAN subnet addresses:

```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
  vlans:
    eth0.11:
      id: 11
      link: eth0
      addresses:
        - 192.168.11.10/24
      routes:
        - to: default
          via: 192.168.11.1
      nameservers:
        addresses: [127.0.0.1]
    eth0.61:
      id: 61
      link: eth0
      addresses:
        - 192.168.61.10/24
```

> **VLAN 61 IP reservation:** `192.168.61.10` is the suggested static IP for the mini PC on VLAN 61. VLAN 61 is newly created and has no existing devices. Before running `netplan apply`, open the Ubiquiti controller and add a fixed IP reservation for the mini PC's MAC address at `192.168.61.10` on VLAN 61, or confirm your DHCP pool for VLAN 61 starts above `.10`. Ubiquiti creates the VLAN gateway (`192.168.61.1`) automatically when the VLAN is configured.

> **Important:** The `nameservers` entry on `eth0.11` points to
> `127.0.0.1`. This is intentional -- once Pi-hole is running, the
> host itself will use it for DNS. Leave this as-is.

Save and close. Apply the configuration:

```bash
sudo netplan apply
```

> **Warning:** If you are connected over SSH, your session will
> disconnect briefly when the network reconfigures. Reconnect using the
> VLAN 11 IP (`192.168.11.10` in the example above).

Verify both interfaces are up:

```bash
ip addr show eth0.11
ip addr show eth0.61
```

Each should show its assigned IP address and `state UP`.

**Find your network interface name:**

If `eth0` does not exist on your system, find the correct name with:

```bash
ip link show
```

Common names are `eth0`, `ens18`, `enp3s0`, or `enp0s3`. Replace `eth0`
everywhere in the Netplan config with whatever name you see.

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

You should see four directories: `dashboards-automation`, `dockge`,
`infrastructure-networking`, `media-gaming`.

---

## 3. Creating Environment Files

Two stacks need a `.env` file before they will start. These files hold
sensitive values (passwords, credentials) and are intentionally not
stored in the repository -- similar to how you would not commit a
`web.config` with connection strings to source control.

### 3.1 infrastructure-networking

```bash
nano /opt/docker/stacks/infrastructure-networking/.env
```

Type the following, replacing the placeholder:

```
PIHOLE_PASSWORD=your-pihole-admin-password
```

Save and close (Ctrl+X, Y, Enter).

This sets the Pi-hole web interface login password. Choose something
strong -- Pi-hole's web interface will be accessible on your network.

### 3.2 media-gaming

```bash
nano /opt/docker/stacks/media-gaming/.env
```

```
DB_USERNAME=immich
DB_PASSWORD=your-database-password
DB_DATABASE_NAME=immich
```

Save and close.

> **Important:** Set `DB_PASSWORD` before you start the stack for the
> first time and do not change it afterwards. This password initialises
> the PostgreSQL database. If you change it after the database exists,
> Immich will fail to connect and you will need to reset the database.

---

## 4. Deploying Stacks

### Order Matters

`dashboards-automation` must be deployed first. It creates a Docker
network called `proxy_net` that every other stack connects to. Think of
it like a virtual switch that the other containers plug in to -- if
`dashboards-automation` is not running, the other stacks cannot start.

### 4.1 dashboards-automation

Navigate to the stack directory and start it:

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

### 4.2 dockge

```bash
cd /opt/docker/stacks/dockge
docker compose up -d
```

### 4.3 infrastructure-networking

```bash
cd /opt/docker/stacks/infrastructure-networking
docker compose up -d
```

Pi-hole takes 20-30 seconds to initialise on first start. Check that
all three containers are running:

```bash
docker compose ps
```

The `STATUS` column should show `running` for `nginx_proxy_manager`,
`pihole`, and `watchtower`. If a container shows `exiting` or
`restarting`, check its logs:

```bash
docker compose logs pihole
```

### 4.4 media-gaming

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

---

## 5. First-Time Service Setup

### 5.1 Dockge

1. Open `http://192.168.11.10:5001` in your browser
2. The first-launch screen asks you to create an admin username and
   password -- do this immediately
3. After logging in, you should see all four deployed stacks listed.
   Green means all containers in that stack are running.

### 5.2 Nginx Proxy Manager

> **Do this immediately after deployment.** NPM ships with a known
> default password and is accessible to anyone on your network.

1. Open `http://192.168.11.10:81`
2. Log in with the default credentials:
   - Email: `admin@example.com`
   - Password: `changeme`
3. NPM will immediately prompt you to update the email and password --
   complete this before closing the browser

**To add a proxy host** (point a domain name at a local service):
- Go to **Hosts > Proxy Hosts > Add Proxy Host**
- **Domain Names:** your domain (e.g. `immich.yourdomain.com`)
- **Forward Hostname / IP:** the container name (e.g. `immich_server`)
  or the host IP
- **Forward Port:** the service's internal port (e.g. `2283` for
  Immich)
- On the **SSL** tab, you can request a free Let's Encrypt certificate
  if your domain has a public DNS record pointing at this host

### 5.3 Pi-hole

Pi-hole is configured entirely through environment variables and does
not require a post-deploy wizard.

1. Open `http://192.168.11.10:8080/admin`
2. Log in with the password from your `infrastructure-networking/.env`
   file
3. The dashboard shows query statistics -- it will be mostly empty
   until clients start using Pi-hole for DNS

**To use Pi-hole as your network DNS resolver:**

Log in to your Ubiquiti router and change the DNS server in the DHCP
settings to the mini PC's LAN IP. Clients will receive it via DHCP and
all DNS queries will route through Pi-hole automatically.

**To add local DNS records** (so `immich.home` resolves to the host IP
without a public domain):
- In Pi-hole: go to **Local DNS > DNS Records**
- Add an entry for each service name you want (e.g. `immich.home` →
  `192.168.x.x`)

### 5.4 Home Assistant

1. Open `http://192.168.11.10:8123`
2. The first-launch wizard guides you through:
   - Creating a user account (this is the HA admin, separate from the
     Linux user)
   - Setting your home location (used for sunrise/sunset automations)
   - Choosing which device types to auto-discover on the network
3. After setup, check the **Notifications** panel (bell icon) for
   detected integrations -- HA will likely have already found devices
   on your network

### 5.5 Homepage

Homepage is configured through YAML files rather than a web UI. The
config files live in `./homepage/config/` on the host
(`/opt/docker/stacks/dashboards-automation/homepage/config/`).

On first start, Homepage creates blank config files automatically. Edit
them to add your services.

Open the services config:

```bash
nano /opt/docker/stacks/dashboards-automation/homepage/config/services.yaml
```

A basic starter configuration:

```yaml
- Infrastructure:
    - Pi-hole:
        icon: pi-hole.png
        href: http://192.168.11.10:8080
        description: DNS filtering
    - Nginx Proxy Manager:
        icon: nginx-proxy-manager.png
        href: http://192.168.11.10:81
        description: Reverse proxy
    - Dockge:
        icon: dockge.png
        href: http://192.168.11.10:5001
        description: Stack manager

- Media:
    - Immich:
        icon: immich.png
        href: http://192.168.11.10:2283
        description: Photo library
    - AMP:
        icon: amp.png
        href: http://192.168.11.10:8081
        description: Game servers
```

Homepage reloads automatically when files are saved -- no container
restart needed. Refresh your browser to see changes.

A full list of supported icons, widgets, and configuration options is
at `https://gethomepage.dev/configs/services/`.

### 5.6 Immich

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

### 5.7 AMP

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

---

## 6. Verification Checklist

Work through this table after completing all setup steps. Every item
should pass before considering the deployment complete.

| Item | How to Verify |
|------|--------------|
| SSH access to host works | You completed this guide |
| proxy_net network exists | `docker network ls \| grep proxy_net` returns one result |
| All containers running | `docker ps` -- no containers showing `Exiting` or `Restarting` |
| Homepage loads | Browse to `http://192.168.11.10:3000` |
| Home Assistant loads | Browse to `http://192.168.11.10:8123` |
| Dockge loads, stacks visible | Browse to `http://192.168.11.10:5001` |
| NPM admin loads, password changed | Browse to `http://192.168.11.10:81` |
| Pi-hole web loads, login works | Browse to `http://192.168.11.10:8080` |
| Pi-hole resolving DNS | Run `nslookup google.com 192.168.11.10` from your Windows machine -- should return an IP |
| Watchtower running | `docker ps \| grep watchtower` shows `Up` |
| Immich loads | Browse to `http://192.168.11.10:2283` |
| Immich ML connected | Administration > Jobs shows machine learning green |
| Immich Postgres healthy | `docker inspect immich_postgres --format '{{.State.Health.Status}}'` returns `healthy` |
| Immich Redis healthy | `docker inspect immich_redis --format '{{.State.Health.Status}}'` returns `healthy` |
| NAS mount present | `df -h \| grep synology` shows the share |
| Intel QS available | `ls /dev/dri` shows `card0` and `renderD128` |
| AMP loads | Browse to `http://192.168.11.10:8081` |

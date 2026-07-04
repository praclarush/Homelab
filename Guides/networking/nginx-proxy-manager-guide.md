# Nginx Proxy Manager Configuration Guide

This guide walks through setting up NPM as a reverse proxy for all homelab services
using a real domain with Let's Encrypt TLS certificates issued via Cloudflare DNS
challenge. When complete, every service is accessible at a clean HTTPS URL (e.g.,
`https://jellyfin.home.bremmer.zone`) with a valid certificate and no browser warnings.

Replace `bremmer.zone` with your actual domain everywhere it appears in this guide.

---

## How It Works

Without NPM you access services by `http://192.168.11.10:3000`, `http://192.168.61.10:8096`,
etc. With NPM and a domain:

1. You browse to `https://jellyfin.home.bremmer.zone`
2. Pi-hole intercepts the DNS query and returns `192.168.11.10` (NPM's IP) instead of
   looking it up publicly -- your services stay private even though the domain is real
3. NPM receives the request on port 443, sees the hostname, and forwards it to the
   `jellyfin` container on port 8096 over the internal Docker network
4. The response returns through NPM with a valid TLS certificate

NPM communicates with containers directly over the `proxy_net` Docker bridge -- no
traffic leaves Docker for services on that network. The domain `home.bremmer.zone`
does not need any public DNS records. Pi-hole handles all resolution internally.
Cloudflare's only role in this setup is issuing the TLS certificate.

---

## Prerequisites

- All stacks deployed and every service reachable at its direct IP:port URL
- Pi-hole running and set as the DNS server in Ubiquiti DHCP for all VLANs
- Your domain is registered and DNS is managed through Cloudflare (see Section 1)

---

## Section 1: Cloudflare Setup

### 1.1 What Cloudflare Does in This Setup

Cloudflare manages your domain's public DNS. In this homelab context it does one
thing: it lets NPM prove domain ownership to Let's Encrypt by creating a temporary
DNS record via the Cloudflare API. That's it.

Your homelab services are never exposed to the internet. No public DNS records are
created for `home.bremmer.zone`. Traffic never goes through Cloudflare's network.
Pi-hole handles all internal DNS resolution. The free Cloudflare plan covers
everything this setup requires.

### 1.2 Add Your Domain to Cloudflare

If your domain is already on Cloudflare, skip to 1.3.

**Domain registration and DNS management are two separate things.** Your domain can
stay registered wherever it is (Namecheap, GoDaddy, Google Domains, etc.) for its
entire life. What you are changing is which company answers DNS queries for that
domain -- you are delegating that authority to Cloudflare by updating the nameservers
at your registrar. NPM's DNS challenge requires Cloudflare's API specifically;
Namecheap's DNS API is not supported by NPM.

**Step 1 -- Add the domain in Cloudflare:**

1. Log into `dash.cloudflare.com` and click **Add a Site**
2. Enter your domain name and click **Continue**
3. Select the **Free** plan and click **Continue**
4. Cloudflare scans your existing DNS records and imports them. Review the list --
   existing records like email (MX, SPF, DKIM) should be preserved. Click **Continue**
5. Cloudflare shows you two nameserver addresses, for example:
   `aria.ns.cloudflare.com` and `bob.ns.cloudflare.com` -- yours will be different.
   Leave this page open.

**Step 2 -- Update nameservers at Namecheap:**

1. Log into Namecheap and go to **Domain List**
2. Click **Manage** next to your domain
3. Under the **Nameservers** section, open the dropdown and select **Custom DNS**
4. Enter the two Cloudflare nameserver addresses from Step 1
5. Click the green checkmark to save

**Step 3 -- Confirm in Cloudflare:**

1. Go back to Cloudflare and click **Done, check nameservers**
2. Cloudflare polls for the change. Propagation typically takes 15 minutes to a few
   hours. Cloudflare sends an email when your domain is active and the dashboard
   status changes from **Pending** to **Active**

> **Your existing DNS records still work.** Cloudflare imported them during the scan
> in Step 1. Verify the imported list before continuing -- especially MX records if
> you have email on this domain.

### 1.3 The Proxy Toggle (Important)

Every DNS record in Cloudflare has a proxy status toggle shown as an orange or grey
cloud icon:

- **Orange cloud (Proxied):** Traffic routes through Cloudflare's CDN. Cloudflare
  sees and can cache the traffic. The real IP address of your server is hidden from
  the public.
- **Grey cloud (DNS only):** Cloudflare publishes a plain DNS record. Traffic goes
  directly to whatever IP the record points to, bypassing Cloudflare entirely.

**For this homelab setup, this toggle does not matter because you are not creating
any public DNS records for `home.bremmer.zone` at all.** Pi-hole handles resolution
internally. But if you ever do add a public record for any homelab subdomain for any
reason, set it to DNS only (grey cloud). A proxied record would route your browser's
request through Cloudflare's servers instead of your local Pi-hole, breaking internal
resolution entirely.

### 1.4 Create an API Token for NPM

NPM needs an API token with permission to edit DNS records in your zone. This allows
it to create the temporary `_acme-challenge` TXT record that Let's Encrypt uses to
verify ownership during certificate issuance.

Use a scoped token -- do not use your Global API Key. A scoped token limits the
damage if it is ever leaked.

1. In Cloudflare, click your profile icon (top right) → **My Profile**
2. Click **API Tokens** in the left sidebar
3. Click **Create Token**
4. Click **Use template** next to **Edit zone DNS**
5. Under **Permissions**, verify it shows:
   - Zone → DNS → Edit
6. Under **Zone Resources**, set the dropdown to **Specific zone** and select your
   domain from the list
7. Leave **IP Address Filtering** blank unless you want to restrict which IP can use
   this token (your home IP changes if you have dynamic internet -- leave blank for now)
8. Click **Continue to summary** → **Create Token**
9. **Copy the token immediately.** Cloudflare shows it exactly once. If you lose it,
   delete the token and create a new one.

This token goes into NPM in Section 3. Store it somewhere secure in the meantime.

---

## Section 2: First Access and Credential Change

NPM admin panel: `http://192.168.11.10:81`

**Default credentials:**

| Field | Value |
|-------|-------|
| Email | `admin@example.com` |
| Password | `changeme` |

NPM forces a credential change on first login:

1. Log in with the defaults above
2. Set your name, a real email address, and a strong password
3. Click **Save**

> **Keep `192.168.11.10:81` bookmarked.** NPM's admin panel is not proxied through
> itself -- if proxy configuration breaks, this direct URL always works.

---

## Section 3: SSL Certificate

This creates a single wildcard certificate covering every subdomain under
`home.bremmer.zone`. You create it once and assign it to every proxy host.

1. In NPM, click **SSL Certificates** in the top navigation
2. Click **Add SSL Certificate**
3. Select **Let's Encrypt**
4. In the **Domain Names** field, add both entries:
   - `*.home.bremmer.zone`
   - `home.bremmer.zone`
5. Toggle **Use a DNS Challenge** on
6. From the DNS Provider dropdown, select **Cloudflare**
7. The Credentials File Content box shows a template. Replace the placeholder value
   with your API token from Section 1.4:
   ```
   dns_cloudflare_api_token = paste-your-token-here
   ```
8. Enter your email address in the **Email Address** field
9. Check **I Agree to the Let's Encrypt Terms of Service**
10. Click **Save**

NPM contacts Let's Encrypt, uses the Cloudflare API to create a temporary TXT record
at `_acme-challenge.home.bremmer.zone`, Let's Encrypt reads it to confirm ownership,
then the record is deleted. The whole process takes about 30 seconds. You will see the
certificate appear in the list with a 90-day expiry -- NPM renews it automatically.

> **If issuance fails:** Check that the API token has **Zone: DNS: Edit** permission
> and is scoped to your domain (not Account-wide read-only). Also verify the Cloudflare
> dashboard shows your domain as **Active**, not **Pending** -- a pending domain means
> nameserver propagation has not completed yet.

---

## Section 4: Wildcard DNS in Pi-hole

One dnsmasq entry routes the entire `home.bremmer.zone` subdomain to NPM. No
additional DNS entries are needed when you add new services later.

SSH into the Linux host and create the config file:

```bash
sudo nano /opt/docker/stacks/infrastructure-networking/pihole/dnsmasq/02-local-dns.conf
```

Add this single line:

```
address=/.home.bremmer.zone/192.168.11.10
```

Save and close (`Ctrl+X`, then `Y`, then `Enter`).

Restart Pi-hole's DNS resolver:

```bash
docker exec pihole pihole restartdns
```

Test from your Windows machine:

```powershell
nslookup anything.home.bremmer.zone 192.168.11.10
```

The response should return `192.168.11.10`. Every subdomain under `home.bremmer.zone`
now resolves to NPM.

> **Why this works even though the domain is real:** Pi-hole intercepts DNS queries
> before they reach your router or the internet. Any query for `*.home.bremmer.zone`
> is answered locally by Pi-hole's dnsmasq rule and never forwarded to Cloudflare.
> This is called split-horizon DNS -- the same domain name returns different results
> depending on who is asking and from where.

---

## Section 5: Creating Proxy Hosts

`Scripts/add-npm-proxy-hosts.ps1` creates every proxy host below in one
run via NPM's API (skips any domain that already exists) -- use it
instead of the manual steps if you'd rather not click through the table
by hand. The manual steps and full field reference below still apply
for one-off additions or troubleshooting.

In NPM, go to **Proxy Hosts** → **Add Proxy Host**.

Each proxy host needs:

- **Domain Names** -- the full subdomain the user types
- **Forward Hostname / IP** -- where NPM sends the request
- **Forward Port** -- the container's internal listening port (not the host port)

**About forward ports:** These are the ports containers listen on inside Docker, not
the host-exposed ports. Grafana listens on `3000` internally even though the host
exposes it as `3002`. Pi-hole listens on `80` internally even though the host exposes
it as `8080`. Always use the internal port.

**About forward hostnames:** All containers except Dockge are on the `proxy_net`
Docker bridge. NPM is also on that network, so it resolves container names directly
without traffic leaving Docker. Dockge has no network configuration in its compose
file and is not on `proxy_net`, so its entry uses the host IP instead.

### Proxy Host Reference

| Service | Domain Name | Forward Host | Port | Websockets |
|---------|-------------|-------------|------|-----------|
| Homepage | `homepage.home.bremmer.zone` | `homepage` | `3000` | Off |
| Home Assistant | `homeassistant.home.bremmer.zone` | `homeassistant` | `8123` | On |
| Uptime Kuma | `uptime.home.bremmer.zone` | `uptime_kuma` | `3001` | On |
| Grafana | `grafana.home.bremmer.zone` | `grafana` | `3000` | Off |
| Prometheus | `prometheus.home.bremmer.zone` | `prometheus` | `9090` | Off |
| Dockge | `dockge.home.bremmer.zone` | `192.168.11.10` | `5001` | Off |
| Pi-hole | `pihole.home.bremmer.zone` | `pihole` | `80` | Off |
| ntfy | `ntfy.home.bremmer.zone` | `ntfy` | `80` | On |
| Authentik | `auth.home.bremmer.zone` | `authentik_server` | `9000` | On |
| WikiJS | `wiki.home.bremmer.zone` | `wikijs` | `3000` | On |
| Immich | `photos.home.bremmer.zone` | `immich_server` | `2283` | On |
| Jellyfin | `jellyfin.home.bremmer.zone` | `jellyfin` | `8096` | On |
| AMP | `amp.home.bremmer.zone` | `amp` | `8081` | Off |
| NAS (DSM) | `nas.home.bremmer.zone` | `<NAS_PRIMARY_IP>` | `5000` | Off |
| Audiobookshelf | `abs.home.bremmer.zone` | `audiobookshelf` | `13378` | On |
| Kavita | `kavita.home.bremmer.zone` | `kavita` | `5000` | On |
| pgAdmin | `pgadmin.home.bremmer.zone` | `pgadmin` | `80` | Off |
| Stirling PDF | `pdf.home.bremmer.zone` | `stirling_pdf` | `8080` | Off |
| Mealie | `mealie.home.bremmer.zone` | `mealie` | `9000` | Off |
| n8n | `n8n.home.bremmer.zone` | `n8n` | `5678` | On |
| IT Tools | `it-tools.home.bremmer.zone` | `it_tools` | `80` | Off |
| Actual Budget | `budget.home.bremmer.zone` | `actual_budget` | `5006` | Off |
| Paperless-ngx | `paperless.home.bremmer.zone` | `paperless_ngx` | `8000` | Off |
| Grocy | `grocy.home.bremmer.zone` | `grocy` | `80` | Off |
| Linkwarden | `links.home.bremmer.zone` | `linkwarden` | `3000` | On |
| Backrest | `backrest.home.bremmer.zone` | `backrest` | `9898` | Off |
| Open WebUI | `llm.home.bremmer.zone` | `open_webui` | `8080` | On |

`infrastructure-networking`'s CrowdSec adds no proxy host of its own. See
[tools-guide.md](../stacks/tools-guide.md), [media-gaming-guide.md](../stacks/media-gaming-guide.md),
and [llm-stack-guide.md](../stacks/llm-stack-guide.md) for service-specific notes
(webhook dependencies, forward-auth requirements, etc.) on the rows above.

### Steps for Each Proxy Host

1. Fill in **Domain Names**, **Forward Hostname / IP**, and **Forward Port**
2. Leave the scheme as **http** -- NPM handles TLS on the client side; containers
   receive plain HTTP internally
3. Toggle **Websocket Support** per the table
4. Toggle **Block Common Exploits** on
5. Click the **SSL** tab:
   - Select the `*.home.bremmer.zone` certificate from the dropdown
   - Toggle **Force SSL** on
   - Toggle **HTTP/2 Support** on
6. Click **Save**

Repeat for every row in the table.

---

### 5.1 Home Assistant -- Extra Configuration Required

Home Assistant rejects proxied requests by default. Two extra steps are required.

**In NPM -- Advanced tab (do this when creating the Home Assistant proxy host):**

Click the **Advanced** tab and paste into the Custom Nginx Configuration box:

```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

**In Home Assistant -- `configuration.yaml`:**

SSH into the host and open the file:

```bash
sudo nano /opt/docker/stacks/dashboards-automation/homeassistant/config/configuration.yaml
```

Add this block at the top level (not nested inside any other block):

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.16.0.0/12
```

`172.16.0.0/12` covers Docker's internal bridge subnet, which is where NPM's
forwarded requests originate. Save and restart:

```bash
cd /opt/docker/stacks/dashboards-automation
docker compose restart homeassistant
```

Without these steps, Home Assistant returns a 400 error for all proxied requests.

---

### 5.2 NAS (Synology DSM)

The NAS is not a Docker container -- NPM reaches it by IP address over the network.

**No firewall rule needed for this.** Per
[`vlan-reference.md`](vlan-reference.md), the NAS lives
on VLAN 61, and the mini PC already has a direct interface there
(`vlan61`) -- the same one `media-gaming`'s services bind to. NPM reaches
the NAS over that same-subnet interface with no inter-VLAN routing or
firewall rule required. If your NAS is reachable at a different IP than
`192.168.61.x`, confirm it's actually on VLAN 61 before troubleshooting
NPM itself.

**NAS IP placeholders:**

Your Synology NAS has two IP addresses. Identify which to proxy and replace the
placeholders:

| Placeholder | Replace With |
|-------------|-------------|
| `<NAS_PRIMARY_IP>` | Primary NAS IP (the one you use to access DSM now) |
| `<NAS_SECONDARY_IP>` | Secondary interface (only needed if it serves a different purpose) |

If both IPs reach the same DSM interface, one proxy host pointing to the primary IP
is sufficient.

**Proxy host settings:**

| Field | Value |
|-------|-------|
| Domain Names | `nas.home.bremmer.zone` |
| Forward Hostname / IP | `<NAS_PRIMARY_IP>` |
| Forward Port | `5000` |
| Scheme | `http` |
| Websocket Support | Off |

> **If DSM redirects HTTP to HTTPS:** DSM defaults to redirecting port 5000 to 5001.
> If NPM gets redirect loops, change the scheme to `https`, the port to `5001`, and
> enable **Disable SSL Verify** in the Advanced tab. DSM's internal certificate is
> self-signed and NPM will reject it without that option. Using port `5000` with
> `http` as the backend scheme avoids this entirely -- disable the DSM HTTP redirect
> under **Control Panel → Login Portal → DSM** if needed.

---

## Section 5.3: Authentik Forward Auth for No-Login Services

Four proxied services have no login of their own: **Homepage**, **Prometheus**
(both above), and **IT Tools** and **Stirling PDF** (in the `tools` stack --
see [tools-guide.md](../stacks/tools-guide.md)). Anyone who can reach
`*.home.bremmer.zone` -- any device on VLAN 11, or anyone who guesses a
subdomain -- gets straight in with zero credentials.

The `auth` stack already runs Authentik specifically to close gaps like this,
but it has never actually been wired into NPM. This section does that, using
Authentik's built-in **embedded outpost** -- no new container, no compose
changes. Do **not** apply this to services that already have their own login
(Grafana, WikiJS, Immich, n8n, pgAdmin, etc.) -- that's redundant, not a gap.
`ntfy` is also unauthenticated by default but is excluded here: it receives
HTTP posts from Watchtower, and a browser-redirect auth flow would break
that. ntfy uses its own auth-file/token mechanism instead -- see
[Section 8.9 of the getting-started guide](../getting-started/homelab-guide.md#89-ntfy).

This uses Authentik's **domain-level** forward auth: one provider protects
the whole `*.home.bremmer.zone` domain via a shared cookie, so adding a fifth
no-login service later only needs the NPM steps in 5.3.2, not a new Authentik
provider.

### 5.3.1 Create the Provider, Application, and Outpost Binding

In Authentik (`https://auth.home.bremmer.zone`, admin interface):

1. **Applications → Providers → Create**
2. Select **Proxy Provider**, click **Next**
3. Name: `NPM Forward Auth`
4. Authorization flow: leave the default (`default-provider-authorization-implicit-consent`)
5. Under **Proxy Type**, select **Forward auth (domain level)**
6. **External host**: `https://home.bremmer.zone`
7. **Cookie domain**: `home.bremmer.zone`
8. Click **Save**

Create the application:

1. **Applications → Applications → Create**
2. Name: `Homelab Forward Auth`
3. Slug: auto-fills as `homelab-forward-auth`
4. **Provider**: select `NPM Forward Auth` from the dropdown
5. Click **Create**

Bind it to the embedded outpost so it's actually served:

1. **Applications → Outposts**
2. Click the pencil icon on **authentik Embedded Outpost**
3. Under **Applications**, move `Homelab Forward Auth` into the selected list
4. Click **Update**

No separate outpost container is needed -- the embedded outpost runs inside
the existing `authentik-server` container on port `9000`, already on
`proxy_net` and already reachable by NPM under the container name
`authentik_server`.

### 5.3.2 Configure Each Protected Proxy Host in NPM

Repeat this for **Homepage**, **Prometheus**, **IT Tools**, and **Stirling
PDF**. Edit the existing proxy host for each (do not create a new one).

**Custom Locations tab:**

1. Click **Add location**
2. **Location**: `/outpost.goauthentik.io`
3. **Scheme**: `http`
4. **Forward Hostname / IP**: `authentik_server`
5. **Forward Port**: `9000`
6. In that location's **Advanced** box, paste:

```nginx
proxy_set_header Host $host;
proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
add_header Set-Cookie $auth_cookie;
auth_request_set $auth_cookie $upstream_http_set_cookie;
proxy_pass_request_body off;
proxy_set_header Content-Length "";
```

**Advanced tab (host-level, not the location's):**

```nginx
auth_request /outpost.goauthentik.io/auth/nginx;
error_page 401 = @goauthentik_proxy_signin;
auth_request_set $auth_cookie $upstream_http_set_cookie;
add_header Set-Cookie $auth_cookie;
auth_request_set $authentik_username $upstream_http_x_authentik_username;
auth_request_set $authentik_groups $upstream_http_x_authentik_groups;
auth_request_set $authentik_email $upstream_http_x_authentik_email;
auth_request_set $authentik_name $upstream_http_x_authentik_name;
auth_request_set $authentik_uid $upstream_http_x_authentik_uid;
proxy_set_header X-authentik-username $authentik_username;
proxy_set_header X-authentik-groups $authentik_groups;
proxy_set_header X-authentik-email $authentik_email;
proxy_set_header X-authentik-name $authentik_name;
proxy_set_header X-authentik-uid $authentik_uid;

location @goauthentik_proxy_signin {
    internal;
    add_header Set-Cookie $auth_cookie;
    return 302 https://auth.home.bremmer.zone/outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri;
}
```

Save the proxy host after both tabs are filled in.

### 5.3.3 Verification

For each of the four services, in a private/incognito browser window:

1. Browse to the service's URL (e.g. `https://prometheus.home.bremmer.zone`)
2. Expect a redirect to `https://auth.home.bremmer.zone` with an Authentik
   login prompt
3. Log in
4. Expect a redirect back to the original service, now loading normally

If instead you get a 502, the Custom Location's forward host/port is wrong or
`authentik_server` isn't reachable on `proxy_net`. If you get stuck in a
redirect loop, double check the **Cookie domain** on the provider is exactly
`home.bremmer.zone` (not `www.home.bremmer.zone` or a specific subdomain).

---

## Section 6: Verification

Work through this table after all proxy hosts are created. Every service should load
over HTTPS with a valid certificate and no browser security warning.

| Service | URL | Expected Result |
|---------|-----|-----------------|
| Homepage | `https://homepage.home.bremmer.zone` | Authentik login, then dashboard loads (Section 5.3) |
| Home Assistant | `https://homeassistant.home.bremmer.zone` | Login page, no 400 error |
| Uptime Kuma | `https://uptime.home.bremmer.zone` | Monitor dashboard |
| Grafana | `https://grafana.home.bremmer.zone` | Login page |
| Prometheus | `https://prometheus.home.bremmer.zone` | Authentik login, then query interface (Section 5.3) |
| Dockge | `https://dockge.home.bremmer.zone` | Stack list |
| Pi-hole | `https://pihole.home.bremmer.zone` | Redirects to `/admin`, loads |
| ntfy | `https://ntfy.home.bremmer.zone` | Notification interface |
| Authentik | `https://auth.home.bremmer.zone` | Login or admin panel |
| WikiJS | `https://wiki.home.bremmer.zone` | Wiki loads |
| Immich | `https://photos.home.bremmer.zone` | Photo library |
| Jellyfin | `https://jellyfin.home.bremmer.zone` | Media library |
| AMP | `https://amp.home.bremmer.zone` | Game server panel |
| NAS | `https://nas.home.bremmer.zone` | Synology DSM login |
| Audiobookshelf | `https://abs.home.bremmer.zone` | Login page |
| Kavita | `https://kavita.home.bremmer.zone` | Library dashboard |
| pgAdmin | `https://pgadmin.home.bremmer.zone` | Login page |
| Stirling PDF | `https://pdf.home.bremmer.zone` | Authentik login, then PDF tools UI (Section 5.3) |
| Mealie | `https://mealie.home.bremmer.zone` | Recipe dashboard |
| n8n | `https://n8n.home.bremmer.zone` | Workflow editor |
| IT Tools | `https://it-tools.home.bremmer.zone` | Authentik login, then tools dashboard (Section 5.3) |
| Actual Budget | `https://budget.home.bremmer.zone` | Budget dashboard |
| Paperless-ngx | `https://paperless.home.bremmer.zone` | Login page |
| Grocy | `https://grocy.home.bremmer.zone` | Login page |
| Linkwarden | `https://links.home.bremmer.zone` | Login page |
| Backrest | `https://backrest.home.bremmer.zone` | Login page |
| Open WebUI | `https://llm.home.bremmer.zone` | Chat interface |

**502 Bad Gateway:** The container is down or the forward hostname/port is wrong.
Check `docker ps | grep <container_name>` and verify the hostname and port in NPM.

**ERR_CERT_AUTHORITY_INVALID:** The certificate was not issued or the wrong one is
selected. Open the SSL Certificates list in NPM and confirm the wildcard cert shows
as valid, not expired or errored.

**DNS not resolving:** Run `nslookup anything.home.bremmer.zone 192.168.11.10` from
Windows. If it fails, check that Pi-hole is running and the dnsmasq config file exists
at `/opt/docker/stacks/infrastructure-networking/pihole/dnsmasq/02-local-dns.conf`.

---

## Section 7: Update Internal Service URLs

Once NPM is routing by domain name, update services that reference each other by
old IP:port URLs.

**Homepage** -- open
`/opt/docker/stacks/dashboards-automation/homepage/config/services.yaml` and replace
`href:` values with HTTPS domains:

```yaml
- Dashboards:
    - Home Assistant:
        href: https://homeassistant.home.bremmer.zone
    - Pi-hole:
        href: https://pihole.home.bremmer.zone
    - Nginx Proxy Manager:
        href: http://192.168.11.10:81
    - Dockge:
        href: https://dockge.home.bremmer.zone
    - Uptime Kuma:
        href: https://uptime.home.bremmer.zone
    - Grafana:
        href: https://grafana.home.bremmer.zone
- Media:
    - Immich:
        href: https://photos.home.bremmer.zone
    - Jellyfin:
        href: https://jellyfin.home.bremmer.zone
    - AMP:
        href: https://amp.home.bremmer.zone
- Infrastructure:
    - NAS:
        href: https://nas.home.bremmer.zone
    - WikiJS:
        href: https://wiki.home.bremmer.zone
    - Authentik:
        href: https://auth.home.bremmer.zone
```

NPM admin stays as a direct IP link -- it is intentionally not proxied through itself.

**WikiJS OIDC (if Authentik SSO is configured)** -- update the redirect URI in the
Authentik application settings from `http://192.168.11.10:3003/...` to
`https://wiki.home.bremmer.zone/...`. Update the matching callback URL in WikiJS
admin under **Authentication → Authentik**.

---

## Maintenance Notes

**Adding a new service:** Create a proxy host in NPM, select the wildcard certificate,
and enable Force SSL. No DNS or Cloudflare changes needed -- the Pi-hole wildcard
covers any new subdomain automatically.

**Certificate renewal:** NPM renews the Let's Encrypt certificate automatically before
the 90-day expiry using the same Cloudflare API token. If renewal fails (token expired
or permission changed), NPM sends an email to your registered address. You can also
trigger a manual renewal from the SSL Certificates list in NPM.

**If your Cloudflare API token expires or is revoked:** Renewal will fail silently
until NPM sends a warning. Create a new token following Section 1.4, then update the
token value in NPM by editing the SSL certificate entry under **SSL Certificates** and
pasting the new token into the Credentials File Content box.

**502 Bad Gateway:** Container is down or forward settings are wrong. Check `docker ps`
and verify the proxy host hostname and port.

**Pi-hole DNS stops resolving domains:** The dnsmasq config file may have been lost if
the container was recreated. Verify the file exists at
`/opt/docker/stacks/infrastructure-networking/pihole/dnsmasq/02-local-dns.conf` and
run `docker exec pihole pihole restartdns` to reload it.

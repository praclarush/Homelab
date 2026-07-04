# LLM Stack Setup Guide

This guide deploys a local LLM stack on the homelab mini PC using
Ollama for model serving and Open WebUI for a browser-based chat
interface. The stack runs fully offline once models are pulled.

> **Hardware note:** This mini PC uses Intel UHD integrated graphics.
> Ollama's GPU acceleration requires NVIDIA (CUDA) or AMD (ROCm) hardware.
> All inference runs on CPU. Expect 3-6 tokens/second for a 14B model.
> This is normal and usable for code generation and chat.

> **Prerequisite:** `infrastructure-networking` must be running before
> deploying this stack. It creates the `proxy_net` Docker bridge network
> that all stacks except `dockge` depend on.

---

## Contents

1. [What This Stack Deploys](#1-what-this-stack-deploys)
2. [Create the Stack Directory](#2-create-the-stack-directory)
3. [Compose File](#3-compose-file)
4. [Environment File](#4-environment-file)
5. [Deploy the Stack](#5-deploy-the-stack)
6. [Pull a Model](#6-pull-a-model)
7. [Verify the Stack](#7-verify-the-stack)
8. [Configure Nginx Proxy Manager](#8-configure-nginx-proxy-manager)
9. [Air-Gapped Operation](#9-air-gapped-operation)
10. [Managing Models](#10-managing-models)

---

## 1. What This Stack Deploys

| Service | Purpose | Port |
|---------|---------|------|
| Ollama | Model server and inference engine | 11434 |
| Open WebUI | Browser-based chat interface | 3004 |

Both services join `proxy_net` so NPM can reach them by container name.
Ollama's API port (11434) is exposed on the host for direct API access
if needed. Open WebUI talks to Ollama over the internal Docker network
using the container name -- no host port needed for that connection.

Model files are stored in `./models` on the host and persist across
container restarts and `docker compose down`.

---

## 2. Create the Stack Directory

On the mini PC host:

```bash
mkdir -p /opt/docker/stacks/llm
cd /opt/docker/stacks/llm
```

---

## 3. Compose File

Create `/opt/docker/stacks/llm/compose.yaml`:

```yaml
networks:
  proxy_net:
    external: true

services:
  ollama:
    container_name: ollama
    image: ollama/ollama:latest
    volumes:
      - ./models:/root/.ollama
    ports:
      - "${VLAN11_IP}:11434:11434"
    mem_limit: 10g
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    restart: unless-stopped
    networks:
      - proxy_net

  open-webui:
    container_name: open_webui
    image: ghcr.io/open-webui/open-webui:main
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    volumes:
      - ./open-webui:/app/backend/data
    ports:
      - "${VLAN11_IP}:3004:8080"
    depends_on:
      - ollama
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    restart: unless-stopped
    networks:
      - proxy_net
```

Open WebUI's login screen is enabled (the default) -- you'll be
prompted to create an admin account on first visit at
`http://192.168.11.10:3004`. The first account created becomes the
admin automatically; sign up immediately after first start so you
don't leave the instance briefly reachable by anyone who gets there
first. If this stack was already running with `WEBUI_AUTH=false` (auth
disabled) and you're now re-enabling it, recreate the container instead
of just restarting so the new setting takes effect:

```bash
docker compose up -d --force-recreate open-webui
```

Sign up immediately after the recreate -- there's a brief window where
anyone who reaches `http://192.168.11.10:3004` first gets the admin
account instead of you. Whether prior chat history carries over to the
new admin account depends on the Open WebUI version running; check
after signing up and treat it as not guaranteed.

### mem_limit and the OOM Killer

`ollama` has a 10GB `mem_limit` -- a hard cap, not a reservation, sized
for models up to `qwen2.5-coder:14b` on the mini PC's 16GB of total RAM.
Raise it if you load a larger model.

The mini PC has 16GB total RAM shared across every stack in this repo
(~30 containers). `ollama`, `immich-machine-learning` (3GB, see
[media-gaming-guide.md](media-gaming-guide.md#4-resource-limits-and-backups)),
and `paperless-ngx` (2GB, see
[tools-guide.md](tools-guide.md#5-resource-limits-and-backups)) are the
only services capped, since they're the only ones capable of consuming
enough memory to starve everything else through the Linux OOM killer,
which otherwise picks a victim somewhat arbitrarily -- it could just as
easily kill a database mid-write as the process actually responsible
for the spike. If you load a model larger than `qwen2.5-coder:14b`,
raise Ollama's `mem_limit` in `compose.yaml` to match, with headroom
for everything else still running.

---

## 4. Environment File

Create `/opt/docker/stacks/llm/.env`:

```text
VLAN11_IP=192.168.11.10
```

---

## 5. Deploy the Stack

```bash
cd /opt/docker/stacks/llm
docker compose up -d
```

Verify both containers are running:

```bash
docker compose ps
```

Expected output: both `ollama` and `open_webui` show `Up`.

Open WebUI will start but show no models until you pull one in the next
step. Ollama itself has no web interface -- it only serves the API.

---

## 6. Pull a Model

Models are pulled while the container is running. The download goes
directly into the `./models` volume on the host.

**Recommended: Qwen2.5-Coder 14B** -- strong at both code and general
chat, fits within the 16 GB RAM constraint with headroom for the OS and
other containers.

```bash
docker exec -it ollama ollama pull qwen2.5-coder:14b
```

The download is roughly 9 GB. Progress is shown in the terminal.

If 14B feels slow after use, the 7B variant gives 2-3x the speed with
a modest quality tradeoff:

```bash
docker exec -it ollama ollama pull qwen2.5-coder:7b
```

You can have multiple models installed simultaneously. Open WebUI lets
you switch between them per conversation.

---

## 7. Verify the Stack

**Check Ollama has the model:**

```bash
docker exec ollama ollama list
```

Expected output: one or more model entries with name, ID, size, and
modification date.

**Check the Ollama API is responding:**

```bash
curl http://192.168.11.10:11434/api/tags
```

Expected output: JSON listing installed models.

**Open the chat interface:**

Navigate to `http://192.168.11.10:3004` in a browser. You should see
the Open WebUI chat interface with the pulled model available in the
model selector dropdown.

Send a test message to confirm end-to-end inference is working.

---

## 8. Configure Nginx Proxy Manager

Add one proxy host in the NPM admin panel (`http://192.168.11.10:81`):

| Field | Value |
|-------|-------|
| Domain name | `llm.home.bremmer.zone` |
| Scheme | `http` |
| Forward hostname | `open_webui` |
| Forward port | `8080` |
| Websockets support | On |
| SSL certificate | `*.home.bremmer.zone` (existing wildcard) |
| Force SSL | On |

Use the internal port `8080`, not the host-mapped `3004`. NPM reaches
Open WebUI by container name over `proxy_net`.

Do not create a proxy host for Ollama's API port (11434) unless you
need external API access. The API has no authentication by default.

---

## 9. Air-Gapped Operation

Once models are pulled, the stack runs without internet access.

- Ollama does not phone home or require network access for inference.
- Open WebUI checks for updates on startup but fails silently with no
  network. Use a pinned image tag to avoid unintended updates:
  change `open-webui:main` to `open-webui:v0.6.5` (or latest stable)
  in `compose.yaml` if this matters to you.
- Model files live in `./models` on the host. They survive container
  removal and image updates.

To add a model after going air-gapped, you need to either restore
internet access temporarily or import the model file manually via
`ollama import`. The simplest path is to pull all models you need
before disconnecting.

---

## 10. Managing Models

List installed models:

```bash
docker exec ollama ollama list
```

Remove a model (frees disk space):

```bash
docker exec ollama ollama rm qwen2.5-coder:7b
```

Pull an additional model:

```bash
docker exec ollama ollama pull <model-name>
```

Browse available models at `https://ollama.com/library`. Notable
options within the 16 GB RAM constraint:

| Model | Pull command | RAM | Notes |
|-------|-------------|-----|-------|
| Qwen2.5-Coder 7B | `qwen2.5-coder:7b` | ~5 GB | Fast, coding + chat |
| Qwen2.5-Coder 14B | `qwen2.5-coder:14b` | ~9 GB | Best balance for this hardware |
| Mistral 7B | `mistral:7b` | ~4.5 GB | Strong general reasoning |
| Llama 3.1 8B | `llama3.1:8b` | ~5 GB | Good general model |
| Gemma 2 9B | `gemma2:9b` | ~6 GB | Google's mid-size model |

Avoid models above 14B on this hardware. A 22B+ model will consume
more RAM than is available after OS and container overhead, causing the
host to swap to disk and making inference unusably slow.

---

## Updating the Stack

```bash
cd /opt/docker/stacks/llm
docker compose pull
docker compose up -d
```

Model files are not affected by image updates. Only the Ollama and
Open WebUI application code changes.

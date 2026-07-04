# Git Deployment Guide

This guide turns `/opt/docker/stacks` on the Ubuntu Server host into a
real git working tree backed by this repository's GitHub remote, so
configuration changes (compose files, `prometheus.yml`, the Pi-hole
dnsmasq conf, Homepage's `services.yaml`, etc.) can be edited on either
the server or a workstation, pushed, and pulled in either direction.
It assumes stacks are already deployed at `/opt/docker/stacks` per
`../getting-started/homelab-guide.md`.

---

## Contents

1. [Why This Needs Care](#1-why-this-needs-care)
2. [Confirm .gitignore Matches the Current Layout](#2-confirm-gitignore-matches-the-current-layout)
3. [SSH Deploy Key Setup](#3-ssh-deploy-key-setup)
4. [Migrating the Live Deployment to a Git Working Tree](#4-migrating-the-live-deployment-to-a-git-working-tree)
5. [Day-to-Day Workflow](#5-day-to-day-workflow)
6. [Adding a New Stack or Service](#6-adding-a-new-stack-or-service)
7. [Verification Checklist](#7-verification-checklist)

---

## 1. Why This Needs Care

Two things make this riskier than a normal `git clone`:

- **`/opt/docker/stacks` is not empty.** It already holds live compose
  files plus every container's persistent data (Postgres volumes,
  caches, models, certificates, Tailscale state). `git clone` refuses
  to clone into a non-empty directory, and you do not want to overwrite
  bind-mounted runtime data while containers are running.
- **`.gitignore` must be correct *before* the first `git status` or
  `git add`**, or you risk committing secrets and multi-gigabyte
  binaries to GitHub: Pi-hole's admin password hash
  (`pihole/config/pihole.toml`), Tailscale's node identity
  (`tailscale/state/`), Home Assistant's auth tokens
  (`homeassistant/config/.storage/`), Ollama model files
  (`llm/models/`), Immich's ML models (`immich/model-cache/`), and
  Paperless-ngx's actual scanned documents (`paperless/media/`) all
  live inside `Docker/stacks/` alongside the compose files you do
  want tracked.

Section 2 confirms the current `.gitignore` is safe before you touch
the live host. Do not skip it.

---

## 2. Confirm .gitignore Matches the Current Layout

The repository's directory layout has been reorganized more than once
(stacks moved from flat top-level folders like `network/` and
`automation/` into `stacks/<stack-name>/`; later, `V1/` and `V2/` version
folders were introduced under a `Docker/` folder; then `V1/` and `V2/`
were flattened away -- `Docker/V2/stacks/`, `Docker/V2/config/`, and
`Docker/V2/guides/` moved up to `Docker/stacks/`, `Docker/config/`, and
`Docker/guides/` directly, and the staged `Docker/V3/` folder moved to
`Docker/Migrations/V3/`; most recently, `Docker/guides/` and
`Docker/Migrations/` moved out from under `Docker/` entirely to become
top-level `Guides/` and `Migrations/`, a top-level `Scripts/` folder was
added, and `hardware-configuration/` moved inside `Guides/` as
`Guides/Hardware-configuration/` -- so the live compose path is now, and
remains, `Docker/stacks/<stack-name>/`).
A `.gitignore` written for an older layout can look correct while
silently not matching anything under the current paths -- patterns
like `network/etc-pihole/*.db` or `media/amp/datastore/` are anchored
to paths that no longer exist, so they ignore nothing.

The repo's `.gitignore` has been updated to use `**/`-prefixed patterns
keyed on the actual directory names under `Docker/stacks/<stack>/`,
so it matches regardless of which stack a directory lives under and
survives future reorganizations of everything above `stacks/`:

```text
**/immich/model-cache/
**/amp/datastore/
**/homeassistant/config/.storage/
**/homeassistant/config/home-assistant.log*
**/pihole/config/
**/tailscale/state/
**/npm/letsencrypt/
**/npm/logs/
**/npm/data/
**/llm/models/
**/open-webui/uploads/
**/paperless/media/
**/paperless/consume/
```

These sit alongside the pre-existing generic rules (`**/postgres/`,
`**/redis/`, `**/cache/`, `**/data/`, `**/*.db`, `**/*.pem`, `.env`,
etc.), which still cover most database and certificate paths.

**Before relying on this anywhere**, verify it against the actual
paths in your deployment from a checkout of the repo:

```bash
git check-ignore -v Docker/stacks/infrastructure-networking/pihole/config/pihole.toml
git check-ignore -v Docker/stacks/infrastructure-networking/tailscale/state/tailscaled.state
git check-ignore -v Docker/stacks/llm/models/somefile.gguf
```

Each should print a matching rule. If any prints nothing, `.gitignore`
needs a new rule for that path before you proceed -- do not continue to
Section 4 until it does. Conversely, confirm files you *want* tracked
still pass through clean (no output, and a non-zero exit code is
expected since they're not ignored):

```bash
git check-ignore -v Docker/stacks/dashboards-automation/homepage/config/services.yaml
git check-ignore -v Docker/stacks/infrastructure-networking/pihole/dnsmasq/02-local-dns.conf
```

---

## 3. SSH Deploy Key Setup

Use a deploy key scoped to this one repository rather than a personal
SSH key or an HTTPS PAT -- nothing to rotate across machines, and it
can be revoked independently of your GitHub account.

On the Ubuntu Server:

```bash
ssh-keygen -t ed25519 -C "ubuntu-server-homelab" -f ~/.ssh/homelab_deploy -N ""
cat ~/.ssh/homelab_deploy.pub
```

In GitHub: repo → **Settings → Deploy keys → Add deploy key** → paste
the public key → check **Allow write access** (required, since you'll
be pushing config edits from the server, not just pulling).

Point git at the key:

```bash
cat >> ~/.ssh/config <<'EOF'
Host github-homelab
  HostName github.com
  User git
  IdentityFile ~/.ssh/homelab_deploy
  IdentitiesOnly yes
EOF
```

A reference copy of this block is at
[`config/operations/ssh-config`](../../Docker/config/operations/ssh-config).

Test it:

```bash
ssh -T github-homelab
```

You should see a message confirming authentication as the repository
(deploy keys do not map to a GitHub username).

---

## 4. Migrating the Live Deployment to a Git Working Tree

Clone to a separate path first -- do not point `git clone` at
`/opt/docker/stacks` directly. Repos live under `/srv/git/`, a
dedicated location kept separate from `/opt/docker` (which holds only
the live stacks symlink and its target).

```bash
sudo mkdir -p /srv/git
sudo chown "$USER:$USER" /srv/git
git clone github-homelab:praclarush/Homelab.git /srv/git/homelab
```

`/srv/git` is created once, owned by your user so subsequent `git`
commands don't need `sudo` -- only the symlink swap into `/opt/docker`
below needs root.

Back up the live stacks directory before changing anything:

```bash
sudo cp -r /opt/docker/stacks /opt/docker/stacks.bak
```

Overlay the live state onto the fresh clone. This brings in your
current compose files, every stack's `.env`, and all gitignored runtime
data (Postgres volumes, caches, models, Tailscale state) -- none of
which exist in the fresh clone, since none of it is tracked:

```bash
sudo rsync -a --exclude='.git' /opt/docker/stacks.bak/ /srv/git/homelab/Docker/stacks/
sudo chown -R "$USER:$USER" /srv/git/homelab
```

`sudo cp -r` above preserves the original ownership of every file it
copies, including root-owned and container-UID-owned paths (Postgres
data directories, Tailscale state, CrowdSec's config and data,
NPM's Let's Encrypt certs, and more). A plain `rsync` run as your user
cannot read those paths in the backup and will fail with `Permission
denied` partway through. Running the `rsync` itself with `sudo` avoids
that, and the follow-up `chown -R` reclaims the working tree for your
user so the `git` commands in the rest of this section don't need
`sudo`. This is safe even for services like Postgres that expect a
specific UID on their data directory -- their container entrypoints
run as root initially and re-`chown` their own data directory to the
UID they need before dropping privileges, so host ownership
self-corrects the next time you run `docker compose up`.

Check what, if anything, has drifted between the live server and
GitHub:

```bash
cd /srv/git/homelab
git status
```

Only tracked files (compose files, `prometheus.yml`, dnsmasq configs,
`homepage/config/services.yaml`, etc.) can show as modified here --
everything else is invisible because it's gitignored. Review any
modified file with `git diff` before deciding whether to commit it.
If `git status` is clean, the server already matches GitHub exactly.

Once satisfied, point the live path at the repo:

```bash
sudo mv /opt/docker/stacks /opt/docker/stacks.old
sudo ln -s /srv/git/homelab/Docker/stacks /opt/docker/stacks
```

`/opt/docker/stacks` is now a symlink into the git working tree.
Dockge's `DOCKGE_STACKS_DIR` and `docker compose` commands run
unchanged from this path -- symlinks are transparent to both. Confirm
every stack still comes up clean:

```bash
for d in /opt/docker/stacks/*/; do
  (cd "$d" && docker compose ps)
done
```

Once you've confirmed nothing broke, remove the now-redundant copies:

```bash
sudo rm -rf /opt/docker/stacks.bak /opt/docker/stacks.old
```

---

## 5. Day-to-Day Workflow

**Editing on the server, then publishing:**

```bash
cd /srv/git/homelab
git add -p
git commit -m "describe the config change"
git push
```

Use `git add -p` rather than `git add -A`. It forces you to review
each hunk before staging, which is what catches a `.gitignore` gap
before it becomes a leaked secret instead of after.

**Pulling a change made elsewhere (e.g. from a Windows checkout):**

```bash
cd /srv/git/homelab
git pull
```

A `git pull` only updates tracked files -- it does not restart
anything. Apply the change by re-running compose in the affected
stack:

```bash
cd /opt/docker/stacks/<stack-name>
docker compose up -d
```

**Before any `git add`,** run `git status` first. If a path you don't
recognize shows up as untracked, treat that as a prompt to add a
`.gitignore` rule -- not as something to add anyway.

---

## 6. Adding a New Stack or Service

The original `.gitignore` gap happened because a directory reorg
changed every stack's path but the `.gitignore` rules stayed anchored
to the old paths. When you add a new stack or a new service to an
existing stack, check before your first commit whether it writes any
of:

- A database or cache directory (usually already covered by the
  generic `**/postgres/`, `**/redis/`, `**/cache/`, `**/data/` rules)
- Downloaded model files, ML artifacts, or other large binaries
- Auth tokens, node identities, or credential files outside `.env`
  (anything under a `state/`, `.storage/`, or similar directory)
- User-generated content (uploads, ingested documents, media libraries)

If so, add a targeted `**/`-prefixed rule for it in `.gitignore` in the
same commit that adds the service -- not after the fact.

---

## 7. Verification Checklist

| Item | How to Verify |
|------|--------------|
| `.gitignore` matches current paths | `git check-ignore -v` on each sensitive path in Section 2 returns a rule |
| Deploy key authenticates | `ssh -T github-homelab` confirms as the repo |
| Repo cloned, not into the live path directly | `/srv/git/homelab/.git` exists |
| Live state reconciled before cutover | `git status` reviewed; no unexpected drift |
| `/opt/docker/stacks` is a symlink | `ls -ld /opt/docker/stacks` shows `-> /srv/git/homelab/Docker/stacks` |
| Dockge still sees all stacks | `http://192.168.11.10:5001` lists every stack, all green |
| All containers still running post-cutover | `docker compose ps` in every stack directory shows `running` |
| Push from server works | Edit a tracked file, `git add -p && git commit && git push`, confirm it appears on GitHub |
| Pull on server works | Make a change elsewhere, push, then `git pull` on the server and confirm the file updated |

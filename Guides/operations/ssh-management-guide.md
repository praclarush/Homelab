# SSH Key Management Guide

This guide consolidates every SSH key involved in operating this homelab --
who holds each private key, what it authenticates to, and how to add,
rotate, or revoke one -- plus a hardening checklist for `sshd` on the
Ubuntu Server host. It assumes the host is already reachable per
`../getting-started/homelab-guide.md` and, if you use the git working
tree workflow, `git-deployment-guide.md`.

---

## Contents

1. [Current Keys at a Glance](#1-current-keys-at-a-glance)
2. [Workstation to Host Access](#2-workstation-to-host-access)
3. [Host to GitHub Access](#3-host-to-github-access)
4. [Naming and authorized_keys Conventions](#4-naming-and-authorized_keys-conventions)
5. [Adding a New Key](#5-adding-a-new-key)
6. [Rotating or Revoking a Key](#6-rotating-or-revoking-a-key)
7. [Hardening sshd](#7-hardening-sshd)
8. [Verification Checklist](#8-verification-checklist)

---

## 1. Current Keys at a Glance

| Key | Lives on | Authenticates to | Purpose |
|-----|----------|-------------------|---------|
| `homelab_personal_ed25519` | Windows workstation (`~/.ssh/`) | `nbremmer@192.168.11.10` (host) | Nathan's personal interactive login |
| `homelab_ed25519` | Windows workstation (`~/.ssh/`) | `nbremmer@192.168.11.10` (host) | Claude Code automation -- must stay passphrase-less so it can be used non-interactively; comment tag in `authorized_keys` is `claude-code-homelab-fix` |
| `homelab_deploy` | Ubuntu Server host (`~/.ssh/`) | GitHub (`praclarush/Homelab` deploy key) | Lets the host `git pull`/`git push` this repo directly -- see [git-deployment-guide.md, Section 3](git-deployment-guide.md#3-ssh-deploy-key-setup) |

Two independent trust directions, three keys. Keeping the personal and
automation workstation keys separate means either one can be revoked
without touching the other -- e.g. if Claude Code's key needs rotating,
Nathan's own login is untouched, and vice versa.

---

## 2. Workstation to Host Access

Both workstation keys authenticate the same way: the public half sits in
`~/.ssh/authorized_keys` on the host (`nbremmer` account), the private
half stays on the workstation. Nothing server-side distinguishes them
beyond the comment on each `authorized_keys` line.

The workstation's `~/.ssh/config` defines both as aliases:

```
Host homelab
  HostName 192.168.11.10
  User nbremmer
  IdentityFile ~/.ssh/homelab_personal_ed25519
  IdentitiesOnly yes

Host homelab-automation
  HostName 192.168.11.10
  User nbremmer
  IdentityFile ~/.ssh/homelab_ed25519
  IdentitiesOnly yes
```

Day to day, connect with:

```bash
ssh homelab
```

The personal key was generated without a passphrase to match the
existing automation key's setup. If you want one, add it after the
fact (this re-prompts interactively and does not change the public key
or require re-adding it to `authorized_keys`):

```bash
ssh-keygen -p -f ~/.ssh/homelab_personal_ed25519
```

---

## 3. Host to GitHub Access

Already covered in full in
[git-deployment-guide.md, Section 3](git-deployment-guide.md#3-ssh-deploy-key-setup):
a repo-scoped deploy key (`~/.ssh/homelab_deploy` on the host), added
under **GitHub repo -> Settings -> Deploy keys** with write access, and
pointed to by the `github-homelab` alias in the host's own
`~/.ssh/config`. Nothing in this guide changes that setup -- it's listed
in Section 1's table for completeness, since it's the third key in the
same overall picture.

---

## 4. Naming and authorized_keys Conventions

Every key, on either side, should be identifiable from its comment
alone -- `ssh-keygen -C "<comment>"` at generation time, or appended
manually to the public key line in `authorized_keys`/GitHub's deploy
key UI. Use `<purpose>-<host-or-user>` (e.g. `nathan-workstation-homelab`,
`ubuntu-server-homelab`), not a generic label -- a future audit of
`authorized_keys` should be able to tell what each line is for and
whether it's still needed without cross-referencing this guide.

---

## 5. Adding a New Key

For a new interactive user or device connecting to the host:

```bash
ssh-keygen -t ed25519 -C "<purpose>-<device>" -f ~/.ssh/<name> -N ""
```

Append the `.pub` contents to `~/.ssh/authorized_keys` on the host (one
line per key -- never overwrite the file):

```bash
cat <name>.pub | ssh homelab 'cat >> ~/.ssh/authorized_keys'
```

For a new deploy key (host or CI system pushing to GitHub), follow
`git-deployment-guide.md` Section 3 instead -- deploy keys are scoped
per-repository through GitHub's UI, not by appending to a local file.

---

## 6. Rotating or Revoking a Key

**Workstation/host keys:** delete the corresponding line from
`~/.ssh/authorized_keys` on the host, then delete the local private
key. Generate a replacement per Section 5 if needed.

**Deploy key:** remove it from **GitHub repo -> Settings -> Deploy
keys**, then delete `~/.ssh/homelab_deploy{,.pub}` on the host and
re-run Section 3 of the deployment guide if a replacement is needed.

Rotate a key immediately (don't wait for a scheduled review) if a
device it lives on is lost, decommissioned, or suspected compromised.

---

## 7. Hardening sshd

The main `/etc/ssh/sshd_config` on the host only sets
`KbdInteractiveAuthentication no`, `UsePAM yes`, `X11Forwarding yes`,
`PrintMotd no`, and an `AcceptEnv` list -- it does not explicitly set
`PasswordAuthentication` or `PermitRootLogin`. A cloud-init-generated
drop-in, `/etc/ssh/sshd_config.d/50-cloud-init.conf`, may already set
these but is root-only (`0600`) and requires `sudo` to read, and the
`nbremmer` account has no `NOPASSWD` rule configured, so this can only
be checked interactively -- run this on the host yourself:

```bash
sudo cat /etc/ssh/sshd_config.d/50-cloud-init.conf
sudo sshd -T | grep -iE 'passwordauthentication|permitrootlogin|pubkeyauthentication'
```

If `passwordauthentication` reports anything other than `no`, add a
hardening drop-in. It must sort alphabetically **before**
`50-cloud-init.conf` for its settings to take precedence (sshd applies
the first value it encounters for a given directive, and `Include` is
the first line of the main config, so drop-ins are read before the
rest of that file, in filename order):

```bash
sudo tee /etc/ssh/sshd_config.d/10-ssh-hardening.conf > /dev/null <<'EOF'
PasswordAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
EOF
sudo sshd -t && sudo systemctl reload ssh
```

`sudo sshd -t` validates the config before reloading -- if it errors,
`systemctl reload ssh` is not run and the live daemon is untouched.
A copy of the recommended drop-in is kept at
[`Docker/config/ssh-hardening.conf`](../../Docker/config/ssh-hardening.conf)
for reference.

**Do not disable password authentication until you've confirmed at
least one key-based login works** (Section 2) -- otherwise a mistake
here can lock out all access to the host.

---

## 8. Verification Checklist

| Item | How to Verify |
|------|--------------|
| Personal key authenticates | `ssh homelab` from the workstation logs in without a password prompt |
| Automation key still works | `ssh homelab-automation` (or `ssh -i ~/.ssh/homelab_ed25519 nbremmer@192.168.11.10`) logs in |
| Deploy key still works | `ssh -T github-homelab` on the host confirms as the repo |
| `authorized_keys` entries are labeled | `cat ~/.ssh/authorized_keys` on the host -- every line has an identifiable comment |
| Password auth disabled (if hardened) | `sudo sshd -T \| grep passwordauthentication` on the host reports `no` |
| Root login restricted | `sudo sshd -T \| grep permitrootlogin` reports `prohibit-password` or `no` |

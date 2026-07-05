# SMTP Relay (Postfix, relaying to Gmail)

**Status: staged, not deployed.** Blocked on generating a Gmail app
password -- no hardware needed.

## What This Is

LAN devices like the Synology NAS can only send notification email
through a plain, unauthenticated SMTP server -- they don't support
storing a Gmail app password or doing STARTTLS auth themselves.
`boky/postfix` runs as a local relay: it accepts unauthenticated mail
from trusted homelab subnets, then relays it out to Gmail over
authenticated SMTP using a stored app password.

```
NAS / other LAN device --> postfix-relay (VLAN11_IP:25, no auth) -->
  smtp.gmail.com:587 (authenticated) --> your inbox
```

This is a straight Compose service addition to `infrastructure-networking`
(same stack as Pi-hole, NPM, ntfy) -- no new hardware, so it's staged here
as a `V2.1` minor update rather than a `V3` item. It's staged as a full
drop-in replacement `compose.yaml` rather than a partial snippet, since
this stack's other services are unaffected and a whole-file swap is
less error-prone than hand-merging one more service block into it.

## What's In This Folder

| File | Purpose |
|------|---------|
| `infrastructure-networking/postfix-relay-service-addition.yaml` | Full drop-in replacement for `Docker/stacks/infrastructure-networking/compose.yaml` -- every existing service unchanged, plus the new `postfix-relay` service appended |
| `infrastructure-networking/env-additions.txt` | New `.env` / `.env.example` variables |

## Generate a Gmail App Password

Requires 2FA enabled on the Google account first.

1. myaccount.google.com/apppasswords
2. Create an app password for "Mail" (name it e.g. `homelab-relay`)
3. Copy the 16-character password -- this is `SMTP_RELAY_PASSWORD` below

## Setup

1. Add the variables from `infrastructure-networking/env-additions.txt`
   to that stack's `.env` (real Gmail address and app password) and
   `.env.example` (blank).
2. Replace `Docker/stacks/infrastructure-networking/compose.yaml`
   entirely with
   `infrastructure-networking/postfix-relay-service-addition.yaml` --
   it's a full copy of the current file with `postfix-relay` appended,
   not a partial snippet to merge by hand. Diff it against the live
   file first to confirm nothing else has drifted since this migration
   was written.
3. Confirm Ubiquiti's inter-VLAN firewall rules allow VLAN 61 (NAS,
   `192.168.61.0/24`) to reach VLAN 11 (`192.168.11.10`) on port 25 --
   traffic already crosses these VLANs for other purposes (e.g. Pi-hole
   DNS), but this is a new port and hasn't been verified yet.
4. `docker compose up -d` in `infrastructure-networking` (picks up
   `postfix-relay` as a new service; existing services are unaffected
   since their definitions are unchanged).

`MYNETWORKS` is set explicitly to `127.0.0.0/8` plus VLANs 11 and 61,
which overrides the image's own auto-detected private-range default. If
another container on `proxy_net` needs to relay through this by
container name rather than `VLAN11_IP`, add `proxy_net`'s actual subnet
too -- confirm it with `docker network inspect proxy_net` first, since
it isn't pinned to a fixed CIDR in `compose.yaml`.

## Verify

```bash
docker exec -it postfix_relay sh -c "echo 'test body' | mail -s 'relay test' you@gmail.com"
```

Check `docker logs postfix_relay` if it doesn't arrive -- the most
common failure is Gmail rejecting the app password (typo, spaces left
in, or 2FA not actually enabled).

Then point the NAS's SMTP notification settings at
`192.168.11.10:25`, no encryption, no auth, and trigger a real test
notification from its UI.

If Gmail starts throttling or bouncing mail from this relay, that's the
sign to swap `RELAYHOST`/`RELAYHOST_USERNAME`/`RELAYHOST_PASSWORD` for a
dedicated transactional provider (Brevo, Mailgun, SES) instead --
same Postfix config, different relayhost.

## Promotion

Once verified:
- Copy `infrastructure-networking/postfix-relay-service-addition.yaml`
  over `Docker/stacks/infrastructure-networking/compose.yaml`, and add
  its variables to that stack's real `.env.example`.
- Add a row to `infrastructure-networking`'s `.env` requirements table
  in the root `CLAUDE.md`.
- Add a short section to
  `Guides/stacks/infrastructure-networking-guide.md` covering the relay
  and how to point additional LAN devices at it.
- Remove `Migrations/V2.1/smtp-relay/` and its row in
  `Migrations/V2.1/README.md`. If `V2.1/` has no other items left,
  remove the whole `V2.1/` folder too.

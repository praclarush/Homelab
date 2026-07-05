# V2.1 — Minor Update to Production

Production is currently running the deployed state under `Docker/` (the
version historically called "V2," collapsed out of its own versioned
folder when the repo was restructured -- see `Docker/stacks/` and
`Docker/config/`). `Migrations/V2.1/` holds a minor, low-risk update to
that running state: a Docker Compose service addition with no hardware
dependency, only a credential to create first. It's tracked as its own
versioned batch rather than a standalone `Migrations/` item because it's
meant to ship as a discrete update to production, the same way `V3/` is
a batch aimed at its own future promotion.

Nothing under `V2.1/` is running yet. Each subfolder is one staged item,
self-contained with its own `README.md`.

## Promotion

Once a `V2.1/` item is verified working:

1. Merge its config into the relevant `Docker/stacks/` service or host
   config, following the existing file layout there.
2. Add or update the relevant guide under `Guides/`.
3. Remove the item's folder from `Migrations/V2.1/`.

## Staged Items

| Item | Depends on | Summary |
|------|-----------|---------|
| [smtp-relay](smtp-relay/README.md) | Gmail app password | Postfix relay container so LAN devices (e.g. the Synology NAS) without their own internet-facing SMTP client can send outbound notification email |

# Host Configuration Reference

This folder holds reference copies of the **Linux host-level**
configuration files the `guides/` walk you through editing -- the ones
that live outside any stack's directory under `stacks/` (`/etc/fstab`,
Netplan, the CrowdSec firewall bouncer config, etc.). They are not
deployed or read by anything automatically; they exist so you can see
the *complete* state of each file in one place, instead of
reconstructing it by reading every guide that touches it.

| File | Introduced by |
|------|---------------|
| `fstab` | NFS mounts for Immich, Jellyfin (`media-gaming`); Audiobookshelf, Kavita (`media-gaming`); Backrest (`tools`) |
| `netplan-00-installer-config.yaml` | VLAN trunk config for the mini PC's two interfaces (VLAN 11, VLAN 61) |
| `crowdsec-firewall-bouncer.yaml` | CrowdSec firewall bouncer override values (`infrastructure-networking`) |

`config/operations/` holds the one host file from
[`guides/operations/git-deployment-guide.md`](../guides/operations/git-deployment-guide.md)
(the SSH config block for the deploy key). It is kept separate from
the files above because it belongs to the git-deployment workflow
rather than to any single stack's initial setup.

## Read This Before Using Any File Here

**`fstab` is NOT a complete `/etc/fstab` file.** A real `/etc/fstab`
has entries for your root partition, swap, and anything else specific
to your install -- none of which this repo knows or controls. The
`fstab` file here contains only the NFS lines the guides add, with a
comment on every line naming the stack and container it serves.
**Append these lines to your existing `/etc/fstab`; never overwrite it.**

**`crowdsec-firewall-bouncer.yaml` is a partial override, not a
complete file.** The full file is generated on the host by the
`crowdsec-firewall-bouncer-nftables` package installer. The guide --
and this reference -- only document the two values it tells you to
change (`api_url`, `api_key`). The rest of that file's contents come
from the package, not from this repository, and are not reproduced here.

**`netplan-00-installer-config.yaml` genuinely is a complete file** --
the getting-started guide has you replace the whole file's contents,
so the copy here is the full, ready-to-adapt file. You still need to
substitute your actual interface name (`eth0` is a placeholder --
check with `ip link show`) and your actual VLAN subnet addresses if
they differ from the examples used throughout the guides.

## Source of Truth

If any file here ever disagrees with the guide that introduced it, the
guide is authoritative -- these are reference copies generated from the
guides, not the other way around.

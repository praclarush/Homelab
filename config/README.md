# Host Configuration Reference

This folder holds reference copies of the **Linux host-level** configuration
files the `guides/` walk you through editing -- the ones that live outside
any stack's directory under `stacks/` (`/etc/fstab`, Netplan, the CrowdSec
firewall bouncer config, etc.). They are not deployed or read by anything
automatically; they exist so you can see the *complete* state of each file
at each version step in one place, instead of reconstructing it by reading
every guide that touched it.

Each `vN/` folder is a complete snapshot as of that version step (matching
the same `v1`-`v5` numbering used across the stack guides). If a file did
not change at a given version, it is still included in that version's
folder, unchanged, for completeness -- the same way each stack's
`compose.vN.yaml` is a complete file rather than a diff.

| Version | Introduces |
|---------|-----------|
| `v1` | NFS mounts for Immich/Jellyfin, VLAN trunk Netplan config |
| `v2` | No new host files (VLAN IPs and NordVPN/Tailscale setup are runtime config, not files added here) |
| `v3` | NFS mounts for Audiobookshelf/Kavita (`media-gaming` v3), CrowdSec firewall bouncer config (`infrastructure-networking` v3) |
| `v4` | No new host files (`tools` v4 services use stack-relative storage only) |
| `v5` | NFS mount for Backrest (`tools` v5) |

`config/operations/` holds the one host file from
[`guides/operations/git-deployment-guide.md`](../guides/operations/git-deployment-guide.md)
(the SSH config block for the deploy key). It isn't tied to a version step --
the git-deployment workflow can be done any time after `v1`, independent of
which stack versions are deployed -- so it is kept separate rather than
duplicated into every `vN/` folder.

## Read This Before Using Any File Here

**`fstab` files are NOT complete `/etc/fstab` files.** A real `/etc/fstab`
has entries for your root partition, swap, and anything else specific to
your install -- none of which this repo knows or controls. Each `fstab`
file here contains only the NFS lines the guides add, with a comment
on every line naming the guide section and stack/container it serves.
**Append these lines to your existing `/etc/fstab`; never overwrite it.**

**`crowdsec-firewall-bouncer.yaml` is a partial override, not a complete
file.** The full file is generated on the host by the
`crowdsec-firewall-bouncer-nftables` package installer. The guide --
and this reference -- only document the two values it tells you to
change (`api_url`, `api_key`). The rest of that file's contents come
from the package, not from this repository, and are not reproduced here.

**`netplan-00-installer-config.yaml` genuinely is a complete file** --
`homelab-v1-guide.md` has you replace the whole file's contents, so the
copy here is the full, ready-to-adapt file. You still need to substitute
your actual interface name (`eth0` is a placeholder -- check with
`ip link show`) and your actual VLAN subnet addresses if they differ
from the examples used throughout the guides.

## Source of Truth

If any file here ever disagrees with the guide that introduced it, the
guide is authoritative -- these are reference copies generated from the
guides, not the other way around.

# VLAN Reference Sheet

**This is the source of truth for VLAN information across this repo.**
Every other doc, guide, and config file that mentions a VLAN ID, name,
subnet, or gateway should agree with this table -- if you ever find one
that doesn't, fix the other file, not this one.

The complete VLAN plan for the home network, as configured on the
Ubiquiti controller. This is whole-network reference, not specific to
the homelab Docker stack -- most of these VLANs exist for general
household network segmentation and have no Docker-relevant content.

| VLAN ID | Name | Subnet | Gateway | Purpose / Typical Devices | Mini PC Presence |
|---------|------|--------|---------|---------------------------|-------------------|
| 1 | Default | `192.168.10.0/24` | `192.168.10.1` | Factory/native management VLAN. No client devices expected here. | No |
| 11 | Services | `192.168.11.0/24` | `192.168.11.1` | Homelab management plane. Every stack except `media-gaming` binds here. | **Yes** -- untagged/native on `enp171s0`, static `192.168.11.10` |
| 20 | Guest | `192.168.20.0/24` | `192.168.20.1` | Guest Wi-Fi, isolated from every other VLAN. | No |
| 30 | IOT | `192.168.30.0/24` | `192.168.30.1` | Smart-home devices -- bulbs, plugs, sensors. | No |
| 31 | Media | `192.168.31.0/24` | `192.168.31.1` | Streaming/casting **client** devices -- Fire TV/Firestick, game consoles. Not the homelab `media-gaming` Docker stack -- see note below. | No |
| 40 | Camera | `192.168.40.0/24` | `192.168.40.1` | IP cameras, NVR. | No |
| 50 | Work | `192.168.50.0/24` | `192.168.50.1` | Work/corporate devices, isolated from the home network. | No |
| 60 | Personal | `192.168.60.0/24` | `192.168.60.1` | Personal/trusted client devices -- phones, laptops. | No |
| 61 | NAS | `192.168.61.0/24` | `192.168.61.1` | Synology NAS. | **Yes** -- tagged `vlan61`, static `192.168.61.10` -- see note below |

Gateway is `192.168.<VLAN ID>.1` for every VLAN **except VLAN 1**,
which deliberately uses `192.168.10.0/24` instead of `192.168.1.0/24`
-- many consumer devices ship with a factory-default IP somewhere in
`192.168.1.0/24`, so keeping the native/default VLAN off that range
avoids collisions when an unconfigured device lands there before being
moved to its proper VLAN.

The mini PC only has a direct interface on VLANs 11 and 61, as
configured in
[`config/netplan-00-installer-config.yaml`](../../config/netplan-00-installer-config.yaml).
VLAN 11 is untagged/native on the physical interface (`enp171s0`
itself carries `192.168.11.10`); VLAN 61 is tagged via a separate
`vlan61` interface carrying `192.168.61.10`. The mini PC reaches every
other VLAN only insofar as Ubiquiti's inter-VLAN routing and firewall
rules allow it -- e.g. Pi-hole answering DNS queries from Guest or IoT
clients.

> **Note:** `ip addr` on the host may also show a `vlan11` interface
> with no IPv4 address. That's a leftover from an earlier config that
> tagged VLAN 11 instead of putting it directly on `enp171s0` --
> netplan/networkd don't tear down old VLAN netdevs without a reboot
> or `ip link delete vlan11`. It's harmless and carries no traffic; the
> current netplan config (above) does not define it.

---

## Why VLAN 61 Is "NAS," Not "Media"

The `media-gaming` stack's host ports (`VLAN61_IP`) -- Immich,
Jellyfin, AMP, Audiobookshelf, and Kavita -- bind to this same VLAN as
the Synology NAS itself. That's intentional, not a naming mistake
carried over from an earlier "Media" label: those services all need
same-subnet NFS access to NAS storage (`/mnt/synology/...`) regardless
of which VLAN their host ports are exposed on, so putting the mini
PC's second interface directly on the NAS's VLAN serves both purposes
with one interface. If you see "VLAN 61 (Media)" anywhere, treat it as
the old label for this same VLAN -- it's the NAS VLAN that the
media-gaming stack happens to also bind to, not a separate media-client
VLAN. Streaming/casting client devices (Firestick, game consoles) live
on the unrelated VLAN 31 above, which the mini PC has no interface on
at all.

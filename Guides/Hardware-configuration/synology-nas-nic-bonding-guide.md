# Synology DS925+ NIC Bonding Guide

This guide covers bonding the two onboard NICs on the Synology DS925+ NAS
into a single failover interface on VLAN 61 (NAS), connected through the
UniFi USW-16-PoE switch. The goal is link/cable redundancy, not
throughput -- see [Why Active/Backup, Not LACP](#4-why-activebackup-not-lacp)
for the reasoning.

For VLAN 61's subnet, gateway, and purpose, see
[`vlan-reference.md`](../networking/vlan-reference.md) -- that file is the
source of truth for VLAN details; this guide only covers the NAS/switch
configuration steps.

---

## Contents

1. [Why This Setup](#1-why-this-setup)
2. [Prerequisites](#2-prerequisites)
3. [Switch Configuration (UniFi Network)](#3-switch-configuration-unifi-network)
4. [Why Active/Backup, Not LACP](#4-why-activebackup-not-lacp)
5. [NAS Configuration (DSM)](#5-nas-configuration-dsm)
6. [Verification](#6-verification)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Why This Setup

The DS925+ has two onboard 2.5GbE LAN ports. The USW-16-PoE is a
Gigabit-only switch (no 2.5GbE or SFP+ ports), so both NAS ports are
capped at 1GbE the moment they connect to it regardless of bonding mode.

Both NICs stay on VLAN 61 only. Do not split them across VLAN 11 and
VLAN 61 -- that would turn the NAS into an unmanaged L2 bridge between
the two VLANs, bypassing the Ubiquiti gateway's inter-VLAN firewall
rules entirely. VLAN 11 clients (Immich, Jellyfin, AMP, etc. on the mini
PC) already reach the NAS over NFS via normal inter-VLAN routing on
VLAN 61 -- see the mini PC's tagged `vlan61` interface in
[`vlan-reference.md`](../networking/vlan-reference.md).

---

## 2. Prerequisites

- Both DS925+ LAN ports physically cabled to the USW-16-PoE.
- Admin access to the UniFi Network application (controller).
- Admin access to DSM on the DS925+.
- The NAS's existing static IP on VLAN 61 (referred to below as
  `<nas-ip>`).

---

## 3. Switch Configuration (UniFi Network)

Active/Backup bonding needs no special switch-side link aggregation
config -- from the switch's perspective, each port is just an
independent access port. The only requirement is that both ports carry
the NAS's VLAN.

1. In UniFi Network, go to **Devices -> USW-16-PoE -> Ports**.
2. Select the port the first NAS NIC is connected to.
3. Set **Native/Network** to the network profile backing VLAN 61 (NAS),
   untagged.
4. Repeat for the port the second NAS NIC is connected to.
5. Apply changes.

If you later decide to switch to LACP (see next section for why this
guide doesn't recommend it by default), the two ports would instead be
combined into a **Link Aggregation Group** under
**Devices -> USW-16-PoE -> Ports -> Create Aggregate Link**, still
scoped to VLAN 61.

---

## 4. Why Active/Backup, Not LACP

DSM offers several bonding modes; the two relevant ones here are:

| Mode | Switch config required | Behavior |
|------|------------------------|----------|
| IEEE 802.3ad (LACP) | Yes -- ports must be a LAG on the switch | Aggregates bandwidth across flows via hashing; a single connection is still capped at one link's speed |
| Active/Backup | No | One NIC active, the other takes over on link failure; no throughput increase |

The USW-16-PoE is a single, non-redundant Gigabit switch. Even with
LACP configured, no single file transfer (an Immich upload, a Jellyfin
stream) exceeds one NIC's 1GbE cap, since LACP only spreads *separate*
flows across links by hash. The homelab's typical access pattern is one
or two concurrent clients, not enough parallel flows to make that
aggregation meaningful.

Active/Backup gets the same real-world throughput with none of the LAG
configuration, and adds cable/port failure tolerance the single-NIC
setup didn't have. Switch to LACP later only if you add a second
switch (removing the single point of failure) or genuinely have enough
concurrent NAS clients to benefit from multi-flow aggregation.

---

## 5. NAS Configuration (DSM)

1. Log in to DSM, open **Control Panel -> Network -> Network Interface**.
2. Click **Manage -> Create -> Create Bond**.
3. Select both onboard LAN interfaces and click **Next**.
4. Choose **Active Backup** as the bonding mode and click **Next**.
5. Configure the bonded interface with the NAS's existing static IP
   (`<nas-ip>`), subnet mask, and VLAN 61 gateway -- do not leave it on
   DHCP.
6. Apply. DSM will briefly drop network connectivity while it
   reconfigures the interfaces.
7. Once DSM is reachable again at `<nas-ip>`, confirm under
   **Control Panel -> Network -> Network Interface** that the new
   `Bond 1` interface shows both LAN ports as members, with one marked
   active.

---

## 6. Verification

1. From a VLAN 61 or VLAN 11 client, confirm the NAS responds:
   ```bash
   ping <nas-ip>
   ```
2. Note which physical port is currently active (DSM's Network
   Interface page shows this under the bond's details).
3. Unplug the active port's cable at the switch.
4. Confirm the ping continues (allow a few seconds for failover) and
   that DSM's Network Interface page now shows the other port as
   active.
5. Reconnect the cable and confirm DSM lists both members again.

---

## 7. Troubleshooting

**Ping stops entirely during the cable-pull test.** Both switch ports
must be on the same VLAN (61) -- if one port was left on the default
network or a different VLAN, failover leaves the bond without a valid
L2 path. Recheck the port profiles in
[section 3](#3-switch-configuration-unifi-network).

**DSM won't let you assign the bond a static IP matching the old
single-NIC IP.** Remove the IP from the original single interface first
(DSM sometimes leaves the address bound to the now-absorbed physical
port) before assigning it to the bond.

**NAS is unreachable immediately after creating the bond.** This is
expected for a few seconds while DSM renegotiates the interface. If it
persists beyond ~30 seconds, connect a monitor/keyboard directly (or
use Synology Assistant on the local subnet) to verify the bond's IP
configuration.

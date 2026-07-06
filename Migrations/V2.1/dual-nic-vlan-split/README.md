# Dual-NIC VLAN Split (Dedicated Physical Port per VLAN)

**Status: staged, not deployed.** Blocked on: running a second Ethernet
cable from the mini PC's second NIC to the switch, and reconfiguring two
Ubiquiti switch ports. No hardware purchase needed -- the Beelink EQi13
already has two onboard NICs, so this ships as a `V2.1` minor update
rather than a `V3` item, the same reasoning as `smtp-relay`.

## What This Is

Today, per
[`vlan-reference.md`](../../../Guides/networking/vlan-reference.md) and
[`netplan-00-installer-config.yaml`](../../../Docker/config/netplan-00-installer-config.yaml),
VLAN 11 and VLAN 61 both ride over the mini PC's single physical NIC
(`enp171s0`): VLAN 11 untagged/native on the switch port, VLAN 61 as an
802.1Q-tagged sub-interface (`vlan61`) on top of the same physical link.
That's a trunk port on the switch and a tagged VLAN sub-interface on the
host.

This item moves VLAN 61 onto the mini PC's second physical NIC instead,
so each VLAN gets its own dedicated port:

- `enp171s0` -- stays on VLAN 11, now a plain access port (no more
  tagged VLAN 61 riding along)
- Second NIC (name TBD, see Setup) -- new access port on VLAN 61,
  replacing the tagged `vlan61` sub-interface entirely

No 802.1Q tagging happens on the host afterward. Practical effects:
each VLAN gets the full link's own bandwidth instead of sharing one
link (relevant for VLAN 61 -- Immich, Jellyfin, and NFS traffic to the
NAS all contend with each other there), and the switch-side config gets
simpler (two access ports instead of one trunk port with tagging
rules to get right).

This does **not** add host redundancy -- it's still one mini PC. If the
host dies, both VLANs go down regardless of which NIC carries which.

## Prerequisites

- [ ] A second Ethernet cable and a free switch port
- [ ] Ubiquiti controller access to reconfigure two switch ports
- [ ] Console/local access to the mini PC (see the safety note in
      Setup step 5 -- a netplan mistake on `enp171s0` can drop your
      only remote path in)

## Setup

### 1. Identify the second NIC's interface name

The kernel enumerates every physical NIC it detects regardless of
cable or link state, so you can do this before running the second
cable:

```bash
for i in /sys/class/net/*; do [ -e "$i/device" ] && basename "$i"; done
```

This filters out virtual interfaces (Docker bridges, veth pairs, any
leftover `vlan61`/`vlan11` netdevs) and lists only real NICs. You
should see `enp171s0` and one other name -- that's the second NIC.
Record its MAC address too, for the optional hardening step below:

```bash
ip link show <SECOND_NIC_NAME>
```

### 2. Run the second cable and reconfigure the switch ports

- Connect the second NIC to a free switch port.
- In the Ubiquiti controller, change **`enp171s0`'s existing port**
  from Trunk (native VLAN 11, tagged VLAN 61) to **Access, VLAN 11**
  -- it no longer needs to carry VLAN 61 at all.
- Set the **new port** (the second NIC's cable) to **Access, VLAN 61**.

### 3. Prepare the netplan file

Copy [`netplan-00-installer-config.yaml`](netplan-00-installer-config.yaml)
from this folder and replace `<SECOND_NIC_NAME>` with the name from
step 1. If you're applying the optional MAC-pinning hardening in that
file's comments, fill in `<SECOND_NIC_MAC>` too.

### 4. Back up the current config on the host

```bash
sudo cp /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.bak-pre-dual-nic
```

### 5. Deploy with `netplan try`, not `netplan apply`

```bash
sudo cp <edited-file> /etc/netplan/00-installer-config.yaml
sudo netplan generate   # syntax check, no changes applied yet
sudo netplan try         # applies, auto-reverts in 120s unless you confirm
```

**Use `netplan try`, not `netplan apply`, for this change.** `enp171s0`
carries your only remote path to this host -- Tailscale and NordVPN
Meshnet both ride over it too, so a mistake here doesn't leave you a
back door, it locks you out entirely. `netplan try` rolls back
automatically if you don't press Enter to confirm within the timeout.
If you have physical/console access to the mini PC, use it for this
step regardless -- confirming a good config remotely and dealing with
a bad one remotely are very different amounts of trouble.

## Verify

```bash
ip addr show enp171s0            # 192.168.11.10/24
ip addr show <SECOND_NIC_NAME>   # 192.168.61.10/24
ip route                         # default route still via 192.168.11.1
ping -c3 192.168.61.1            # VLAN 61 gateway reachable
df -h | grep synology            # NFS mounts still up (media-gaming, backups)
```

Then confirm the stacks: `docker compose ps` in each stack directory
should show everything `Up`, and a couple of proxied URLs
(`https://photos.home.bremmer.zone`, `https://jellyfin.home.bremmer.zone`)
should load normally -- both depend on the VLAN 61 path staying intact
through this change.

## Promotion

Once verified stable (through at least one host reboot, to confirm the
interface names don't shuffle):

1. Replace
   [`Docker/config/netplan-00-installer-config.yaml`](../../../Docker/config/netplan-00-installer-config.yaml)
   with the finalized version from this folder (placeholders filled
   in) and deploy it as the new `/etc/netplan/00-installer-config.yaml`
   reference copy.
2. Update
   [`Guides/networking/vlan-reference.md`](../../../Guides/networking/vlan-reference.md):
   the "Mini PC Presence" column and the paragraph below the table
   currently describe VLAN 61 as tagged on `enp171s0` -- change it to
   describe two dedicated physical NICs, no tagging.
3. Update the netplan row in
   [`Docker/config/README.md`](../../../Docker/config/README.md) --
   it currently says "VLAN trunk config for the mini PC's two
   interfaces"; that should become "VLAN config for the mini PC's two
   dedicated physical NICs (no trunking)".
4. Remove `Migrations/V2.1/dual-nic-vlan-split/` and its row in
   [`Migrations/V2.1/README.md`](../README.md). If `V2.1/` has no other
   items left, remove the whole `V2.1/` folder too.

No Docker Compose or `.env` changes are needed anywhere -- every
stack's `VLAN61_IP`/`VLAN11_IP` binding is just a static IP the host
happens to own; Docker's routing doesn't care which physical NIC
backs that route.

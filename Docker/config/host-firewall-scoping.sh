#!/bin/sh
# Host firewall scoping for DNS (53), rpcbind (111), and node-exporter (9100)
#
# Reference only -- see config/README.md. This is a complete,
# ready-to-run script, not a partial override. Run it with sudo on
# the host after reviewing it -- it is not applied automatically by
# anything in this repo.
#
# Why this exists: a full security audit (2026-07-26) found these
# three ports reachable from every network the host touches --
# including Tailscale and Meshnet -- when each was only ever meant to
# serve a specific network:
#   - Pi-hole DNS (53): meant for devices on the home network's VLANs
#     (all of them -- Pi-hole is the household's DNS resolver), but
#     NOT for remote Tailscale/Meshnet-connected devices.
#   - rpcbind (111): only needed between this host and the Synology
#     NAS, both on VLAN 61.
#   - node-exporter (9100): only needed by Prometheus, which lives on
#     VLAN 11. Unauthenticated by design -- exposing it anywhere else
#     leaks host metrics (mounts, process/cgroup detail) to anyone
#     who can reach it.
#
# ufw is installed on this host but was never actually enabled (no
# default-deny policy, no existing rule set) -- see
# guides/operations (Homelab-wiki) for that discovery. Standing up
# ufw properly for the whole host is a much bigger, riskier project
# (every port across every stack would need an explicit allow rule
# before flipping ufw to default-deny). This script instead adds a
# small, targeted iptables/ip6tables rule set for just these three
# ports, via the DOCKER-USER chain (for the Docker-published Pi-hole
# port) and the INPUT chain (for the two bare host-network services),
# leaving every other port exactly as reachable as it is today.
#
# iptables here means iptables-nft (confirmed via
# `update-alternatives --display iptables`) -- this host's kernel
# only has nf_tables loaded, not legacy iptables/ip_tables, same
# constraint documented in CLAUDE.md for the Tailscale/CrowdSec setup.
#
# Ordering matters and is easy to get backwards by hand:
#   - DOCKER-USER: Docker appends its own default RETURN rule at
#     chain creation, so new rules MUST be inserted at position 1
#     (`-I DOCKER-USER 1`), never appended (`-A`), or they'd sit after
#     Docker's default and never be evaluated.
#   - INPUT: nothing else currently manages these ports at the INPUT
#     level, so rules are appended (`-A`) in the natural order they
#     should be evaluated: specific ACCEPTs first, catch-all DROP last.

set -e

echo "== Installing iptables-persistent (answer yes to both save prompts) =="
DEBIAN_FRONTEND=dialog apt install iptables-persistent

echo "== Pi-hole DNS (53): block Tailscale and Meshnet, leave every VLAN untouched =="
# Docker forwards published-container-port traffic through DOCKER-USER
# before it reaches the container, so this is the correct chain for a
# port published via `ports:` in compose -- not INPUT.
iptables  -I DOCKER-USER 1 -p udp --dport 53 -i tailscale0 -j DROP
iptables  -I DOCKER-USER 1 -p tcp --dport 53 -i tailscale0 -j DROP
iptables  -I DOCKER-USER 1 -p udp --dport 53 -i nordlynx   -j DROP
iptables  -I DOCKER-USER 1 -p tcp --dport 53 -i nordlynx   -j DROP

echo "== rpcbind (111): restrict to VLAN 61 (NAS) and localhost only =="
# rpcbind is a bare host service (not a container), so INPUT is the
# right chain. Dual-stack (listens on both 0.0.0.0 and ::), so both
# iptables and ip6tables need rules. There's no legitimate IPv6 NFS
# use case here at all (the NAS and VLAN 61 are IPv4-only), so IPv6
# is dropped outright rather than allow-listed.
iptables  -A INPUT -p tcp --dport 111 -s 127.0.0.1      -j ACCEPT
iptables  -A INPUT -p udp --dport 111 -s 127.0.0.1      -j ACCEPT
iptables  -A INPUT -p tcp --dport 111 -s 192.168.61.0/24 -j ACCEPT
iptables  -A INPUT -p udp --dport 111 -s 192.168.61.0/24 -j ACCEPT
iptables  -A INPUT -p tcp --dport 111 -j DROP
iptables  -A INPUT -p udp --dport 111 -j DROP
ip6tables -A INPUT -p tcp --dport 111 -j DROP
ip6tables -A INPUT -p udp --dport 111 -j DROP

echo "== node-exporter (9100): restrict to VLAN 11 (Prometheus) and localhost only =="
# Runs with network_mode: host, so it's indistinguishable from a bare
# host service at the packet-filtering level -- INPUT chain, same as
# rpcbind. Dual-stack (Go's net/http binds both families under one
# socket when given an empty host), no legitimate IPv6 consumer here
# either, so IPv6 is dropped outright.
iptables  -A INPUT -p tcp --dport 9100 -s 127.0.0.1       -j ACCEPT
iptables  -A INPUT -p tcp --dport 9100 -s 192.168.11.0/24 -j ACCEPT
iptables  -A INPUT -p tcp --dport 9100 -j DROP
ip6tables -A INPUT -p tcp --dport 9100 -j DROP

echo "== Persisting rules across reboots =="
netfilter-persistent save

echo "== Done. Verify with: =="
echo "  iptables -L DOCKER-USER -n --line-numbers"
echo "  iptables -L INPUT -n --line-numbers"
echo "  ip6tables -L INPUT -n --line-numbers"

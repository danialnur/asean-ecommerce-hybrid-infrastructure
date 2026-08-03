# Phase 3 — IP Services, Layer 2 Active Defense & ACL Plan

Reference plan for Phase 3 (`02-security-hardening/`). Built the same way the Phase 1/2 addressing plans
were — design first, then type it in device by device. Maps to CCNA 200-301 Domains 4.0/5.0 and
Security+ SY0-701 Domains 1.0/2.0/4.0.

## Server inventory

Phase 3's IP services all point at one consolidated address sitting in Malaysia HQ's `DMZ_SERVERS` VLAN — which
is exactly what that VLAN's description already says it's for ("TFTP / SIEM / RADIUS"). It started life as a
placeholder address with no device behind it, but the first real TFTP backup attempt against it genuinely timed
out, so a real Packet Tracer Server device (`MY-KL-DMZ-SRV`) was added on `MY-KL-HQ-CORE`'s `Gi1/0/21` rather than
just documenting the failure — see `evidences/README.md`'s "TFTP Configuration Backup" section for the full
before/after evidence. It currently runs TFTP and Syslog for real; SNMP trap receipt, DHCP, and RADIUS are still
configured as targets on the network devices but not verified against a live service on the server itself.

| Service | Address | Notes |
|---|---|---|
| `MY-KL-DMZ-SRV` (TFTP, Syslog; DHCP/RADIUS/SNMP-trap-receiver configured as targets but not live-verified) | `10.10.40.10` | Single consolidated host — a real deployment would likely split these across dedicated hosts, but one address is enough to demonstrate every protocol correctly |
| NTP source | `MY-KL-HQ-CORE` itself (`ntp master`) | No real internet-reachable NTP server exists in this lab, so Malaysia HQ is designated the authoritative internal time source, matching real practice for isolated/lab networks |

## ACL policy design

Two ACLs, chosen specifically to cover both the **standard** and **extended**, **IPv4** and **IPv6** requirements
with policies that actually mean something in this topology, rather than arbitrary examples:

### 1. Standard ACL — restrict VTY/SSH management access to MGMT subnets only

Applied via `access-class <name> in` (IPv4) / `ipv6 access-class <name> in` (IPv6) under `line vty` on **every
device**. Only someone whose traffic originates from a MGMT subnet can even attempt to SSH in — everyone else's
connection attempt is dropped before authentication is ever considered.

| Permitted source (MGMT subnets) |
|---|
| `10.10.10.0/24` (Malaysia) |
| `10.10.110.0/24` (Manila) |
| `10.10.120.0/24` (Bangkok) |
| `2001:db8:1:10::/64` (Malaysia, IPv6) |
| `2001:db8:3:10::/64` (Manila, IPv6) |
| `2001:db8:4:10::/64` (Bangkok, IPv6) |

### 2. Extended ACL — contain GUEST_WIFI

Applied inbound on the interface where each site's GUEST_WIFI traffic first reaches a router (`MY-KL-HQ-CORE`'s
`Vlan30`, `PH-MNL-ROAS`'s `Gi0/0/0.30`, `TH-BKK-ROAS`'s `Gi0/0/0.30`) — filtering as close to the source as
possible, standard ACL placement practice. Guests get denied from every internal business/management subnet
across all three sites, not just their own site — this directly implements the blueprint's example ("blocking
Manila/Bangkok guest VLANs from accessing Malaysia HQ Finance databases") and extends it consistently everywhere.

| Rule | Source | Destination | Action |
|---|---|---|---|
| 1 | GUEST_WIFI (any site) | MGMT (any site) | **Deny** |
| 2 | GUEST_WIFI (any site) | LOGISTICS_SALES (any site) | **Deny** |
| 3 | GUEST_WIFI (any site) | DMZ_SERVERS (any site) | **Deny** |
| 4 | GUEST_WIFI (any site) | anything else | **Permit** |

Everything else in the topology (LOGISTICS_SALES ↔ DMZ_SERVERS, cross-site LOGISTICS_SALES traffic, etc.) stays
permitted by default — no ACL restricts it, since there's no business reason to.

## DHCP Relay scope

`ip helper-address 10.10.40.10` applied only on the two VLANs where real end-user devices would actually request
a DHCP lease — **LOGISTICS_SALES (20)** and **GUEST_WIFI (30)**. `MGMT` and `DMZ_SERVERS` are infrastructure/admin
subnets that would use static addressing in a real deployment, so no relay is configured there.

**Live-tested end-to-end, and it genuinely failed the first time — a real finding, not a formality.** A DHCP
pool (`LOGISTICS_SALES`, gateway `10.10.20.1`, range from `10.10.20.50`) was added to `MY-KL-DMZ-SRV`, and a test
PC on `Vlan20` requested a lease through the relay. First attempt failed outright (APIPA fallback,
`DHCP Servers: 0.0.0.0`) despite the relay config, the pool, and the port/VLAN all being individually correct.
Root cause: DHCP Snooping was silently dropping the server's `OFFER`/`ACK` replies, because `Gi1/0/21` (the port
`MY-KL-DMZ-SRV` sits on) was never marked as a **trusted** DHCP snooping port - and DHCP snooping only accepts
server-originated messages on trusted ports, dropping everything else with no log or error visible from the
client side. Adding `ip dhcp snooping trust` to `Gi1/0/21` fixed it immediately - retried and the client leased
`10.10.20.50` for real, with `DHCP Servers: 10.10.40.10` in its own `ipconfig /all`, proving the reply genuinely
crossed the relay rather than coming from somewhere local. This also resolves the open question flagged in
`evidences/README.md`'s DHCP Snooping section about whether `MY-KL-HQ-CORE` having zero trusted interfaces was a
gap or intentional - it was a real gap. See `evidences/dhcp-relay/` for the before/after evidence.

## TFTP configuration backup — an EXEC workflow, not stored config

Unlike everything else in this phase, `copy running-config tftp:` is an **interactive EXEC command**, not a
configuration line — it never appears in any `.cfg` reference file, the same way `crypto key generate rsa` never
shows up in `show running-config`. Run it on each device once its Phase 1-3 config is complete:

```
copy running-config tftp:
Address or name of remote host []? 10.10.40.10
Destination filename [my-kl-hq-core-confg]? my-kl-hq-core-2026-07-26.cfg
```
(swap the filename per device — including a date makes it obvious which backup is the latest if you ever repeat
this later in the project)

**Verify** with `show start`/checking IOS's confirmation message that the transfer succeeded (`OK` and a byte
count). This is real, portfolio-relevant evidence of the CCNA 4.9 "perform IOS configuration and image
backups/restorations via TFTP" objective — worth a screenshot of the copy confirmation once you run it.

## Packet Tracer Simulation Mode — TCP vs UDP capture (replaces a real Wireshark capture)

Real Wireshark can't see Packet Tracer's simulated traffic (it never touches your host's real NIC — see the PCAP
discussion earlier in this project). Simulation Mode is the correct, and only, way to capture *this lab's* actual
packets with real protocol detail.

**To capture a TCP 3-way handshake (SSH, port 22):**
1. Switch Packet Tracer to **Simulation Mode** (bottom-right, next to Realtime).
2. From one device's CLI, start an SSH session toward another (e.g. `PH-MNL-ACC` → `PH-MNL-ROAS`,
   `ssh -l asean.admin 10.10.110.1`).
3. Step through the captured events one at a time (the "Play"/"Step" controls) and click each SSH-related packet
   to open its PDU details — you'll see the TCP SYN, SYN-ACK, ACK sequence explicitly, plus the encrypted SSH
   payload afterward.
4. Screenshot the PDU detail view showing the flag fields (`SYN`, `ACK`) across the three packets.

**To capture UDP (Syslog or SNMP, both connectionless):**
1. Trigger an SNMP poll or a syslog event (e.g. a port-security violation, or just waiting for an SNMP trap you
   configured earlier in this phase) while still in Simulation Mode.
2. Click the UDP packet's PDU details — notice there's no handshake at all: a single datagram, no SYN/ACK
   negotiation, no connection state — this is the concrete side-by-side contrast the CCNA 1.5 objective is
   actually testing (TCP's connection-oriented reliability vs UDP's fire-and-forget delivery).
3. Screenshot both PDU detail views side by side, or as two separate images captioned to show the contrast.

Save these into `02-security-hardening/threat-simulations/` per the repo structure, with captions explaining what
each one demonstrates (same documentation approach as the `screenshots/` folders discussed earlier).

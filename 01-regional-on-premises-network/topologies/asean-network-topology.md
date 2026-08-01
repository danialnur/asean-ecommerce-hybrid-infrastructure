# AREHI-SECOPS — Regional On-Premises Topology & IPv4 Addressing Plan

Phase 1 reference topology and VLSM plan for the four on-premises sites. This
is the source of truth the configs in `switching/` and `router-configs/` were
built from — update this file first if the addressing scheme changes.

## Logical topology (hub-and-spoke, Malaysia HQ as hub)

```text
                                   ┌───────────────────────────────┐
                                   │     SG-EDGE-GW           │
                                   │     Singapore WAN Edge         │
                                   │  Gi0/0/1 → AWS ap-southeast-1  │
                                   │  (IPsec S2S VPN, Phase 4)      │
                                   └───────────────┬────────────────┘
                                                    │ Gi0/0/0
                                                    │ 10.10.254.2/30
                                                    │
                                                    │ Gi1/0/24
                                                    │ 10.10.254.1/30
                        ┌───────────────────────────┴───────────────────────────┐
                        │              MY-KL-HQ-CORE                       │
                        │        Malaysia HQ — Core/Distribution (L3)           │
                        │  VLAN10 MGMT · VLAN20 LOGISTICS_SALES                 │
                        │  VLAN30 GUEST_WIFI · VLAN40 DMZ_SERVERS · VLAN99 NATIVE│
                        │  HSRP active on all SVIs (priority 150)               │
                        └───────┬───────────────────────────────────┬───────────┘
                    Gi1/0/23    │                                   │  Gi1/0/22
                 10.10.254.5/30 │                                   │  10.10.254.9/30
                                │                                   │
                    Gi0/0/1     ▼                                   ▼    Gi0/0/1
                 10.10.254.6/30 ┌─────────────────────┐  ┌─────────────────────┐ 10.10.254.10/30
                                │  PH-MNL-ROAS   │  │  TH-BKK-ROAS  │
                                │  Manila ROAS router  │  │  Bangkok ROAS router│
                                └──────────┬───────────┘  └──────────┬──────────┘
                                Gi0/0/0 (single trunk,        Gi0/0/0 (single trunk,
                                    802.1Q sub-ifs)               802.1Q sub-ifs)
                                           │                          │
                                ┌──────────▼───────────┐   ┌──────────▼──────────┐
                                │  PH-MNL-ACC      │   │  TH-BKK-ACC    │
                                │  Manila access switch │   │  Bangkok access sw  │
                                │  Barcode/inventory     │   │  Barcode/inventory  │
                                │  terminals, guest AP   │   │  terminals, guest AP│
                                └────────────────────────┘   └──────────────────────┘
```

Malaysia HQ is the only site that routes locally (SVIs on the core switch,
HSRP for gateway redundancy). Manila and Bangkok use router-on-a-stick since
their access switches are Layer 2 only. Singapore has no local VLANs — it
exists purely as the WAN-to-cloud on-ramp.

## Device inventory

| Hostname                | Role                              | Platform          | Site           |
|--------------------------|-----------------------------------|--------------------|----------------|
| `MY-KL-HQ-CORE`     | Core/distribution switch (L3)     | Catalyst 3650-24PS | Kuala Lumpur   |
| `MY-KL-HQ-DIST`     | Distribution switch - LACP EtherChannel peer for MY-KL-HQ-CORE (Gi1/0/1-2, Port-channel1) | Catalyst 3650-24PS | Kuala Lumpur |
| `SG-EDGE-GW`       | WAN edge / cloud on-ramp router   | ISR 4331           | Singapore      |
| `PH-MNL-ROAS`      | Router-on-a-stick                 | ISR 4321           | Manila         |
| `PH-MNL-ACC`        | Access switch (L2)                | Catalyst 2960-24TT | Manila         |
| `TH-BKK-ROAS`      | Router-on-a-stick                 | ISR 4321           | Bangkok        |
| `TH-BKK-ACC`        | Access switch (L2)                | Catalyst 2960-24TT | Bangkok        |
| `MY-KL-DMZ-SRV`     | Core services server (TFTP / Syslog / SNMP trap receiver), `MY-KL-HQ-CORE` `Gi1/0/21`, VLAN 40 | Packet Tracer Server device | Kuala Lumpur |

`MY-KL-HQ-DIST` isn't part of the routed hub-and-spoke topology above - it exists solely so `MY-KL-HQ-CORE`'s
LACP EtherChannel (`Port-channel1`) has a real peer to bundle with. Nothing else in this project routes through
or depends on it, so it's out of scope for the Phase 3 security-hardening pass (no SSH/port-security/ACL
hardening applied there).

`MY-KL-DMZ-SRV` was added mid-Phase 3, after the first TFTP backup attempt against the `10.10.40.10` placeholder
genuinely timed out with no device behind it - see `../../02-security-hardening/evidences/README.md`'s "TFTP
Configuration Backup" section for the full before/after evidence.

## IPv4 VLSM plan

Parent block: `10.10.0.0/16`, subdivided into per-site /24s. Malaysia HQ keeps
the VLAN ID as the third octet (its own convention as the hub); Manila and
Bangkok each get a contiguous block of four /24s so no site's subnets overlap
on the shared OSPF Area 0 backbone (Phase 2).

| Site      | VLAN | Name             | Subnet            | Gateway (.1)                  | Notes |
|-----------|------|------------------|--------------------|--------------------------------|-------|
| Malaysia  | 10   | MGMT             | 10.10.10.0/24      | HSRP VIP on MY-KL-HQ-CORE      | Core switch phys IP `.2` |
| Malaysia  | 20   | LOGISTICS_SALES  | 10.10.20.0/24      | HSRP VIP on MY-KL-HQ-CORE      | Core switch phys IP `.2` |
| Malaysia  | 30   | GUEST_WIFI       | 10.10.30.0/24      | HSRP VIP on MY-KL-HQ-CORE      | Core switch phys IP `.2` |
| Malaysia  | 40   | DMZ_SERVERS      | 10.10.40.0/24      | HSRP VIP on MY-KL-HQ-CORE      | TFTP / SIEM / RADIUS |
| Manila    | 10   | MGMT             | 10.10.110.0/24     | ROAS router `.1`               | Switch mgmt IP `.2` |
| Manila    | 20   | LOGISTICS_SALES  | 10.10.111.0/24     | ROAS router `.1`               | Barcode/inventory terminals |
| Manila    | 30   | GUEST_WIFI       | 10.10.112.0/24     | ROAS router `.1`               | Autonomous AP, no WLC |
| Manila    | 40   | DMZ_SERVERS      | 10.10.113.0/24     | ROAS router `.1`               | |
| Bangkok   | 10   | MGMT             | 10.10.120.0/24     | ROAS router `.1`               | Switch mgmt IP `.2` |
| Bangkok   | 20   | LOGISTICS_SALES  | 10.10.121.0/24     | ROAS router `.1`               | Barcode/inventory terminals |
| Bangkok   | 30   | GUEST_WIFI       | 10.10.122.0/24     | ROAS router `.1`               | Autonomous AP, no WLC |
| Bangkok   | 40   | DMZ_SERVERS      | 10.10.123.0/24     | ROAS router `.1`               | |

## WAN transit links (`10.10.254.0/24`, /30 each)

| Link              | Subnet             | MY HQ side           | Remote side              |
|-------------------|---------------------|------------------------|----------------------------|
| MY ↔ Singapore    | 10.10.254.0/30      | `.1` Gi1/0/24          | `.2` SG-EDGE-GW Gi0/0/0 |
| MY ↔ Manila       | 10.10.254.4/30      | `.5` Gi1/0/23          | `.6` PH-MNL-ROAS Gi0/0/1 |
| MY ↔ Bangkok      | 10.10.254.8/30      | `.9` Gi1/0/22          | `.10` TH-BKK-ROAS Gi0/0/1 |

## Public / cloud-facing addressing

| Interface                          | Address                    | Notes |
|--------------------------------------|------------------------------|-------|
| `SG-EDGE-GW` Gi0/0/1           | 203.0.113.2/29 (RFC 5737 doc range placeholder) | IPsec S2S VPN tunnel source to AWS VGW, built in Phase 4 |
| AWS VPC (ap-southeast-1)             | 10.200.0.0/16               | Built in Phase 4 (`03-aws-cloud-infrastructure/`) |

## Phase 2 — IPv6 dual-stack addressing plan

Parent block: `2001:db8::/32` (RFC 3849 documentation prefix — the IPv6 equivalent of the IPv4 `203.0.113.0/24`
placeholder used for `SG-EDGE-GW`'s cloud-facing interface). Each site gets a `/48`; each VLAN within a site gets
a `/64` carved out of it — `/64` is mandatory for SLAAC and modified EUI-64 to function, so unlike IPv4 there's no
finer VLSM subdivision at the LAN edge.

| Site | IPv6 site block |
|---|---|
| Malaysia (HQ) | `2001:db8:1::/48` |
| Singapore (WAN edge, no local VLANs) | `2001:db8:2::/48` |
| Manila | `2001:db8:3::/48` |
| Bangkok | `2001:db8:4::/48` |
| WAN transit links (cross-site, doesn't belong to one site) | `2001:db8:ff::/48` |

| Site | VLAN | Subnet |
|---|---|---|
| Malaysia | 10 MGMT | `2001:db8:1:10::/64` |
| Malaysia | 20 LOGISTICS_SALES | `2001:db8:1:20::/64` |
| Malaysia | 30 GUEST_WIFI | `2001:db8:1:30::/64` |
| Malaysia | 40 DMZ_SERVERS | `2001:db8:1:40::/64` |
| Manila | 10 MGMT | `2001:db8:3:10::/64` |
| Manila | 20 LOGISTICS_SALES | `2001:db8:3:20::/64` |
| Manila | 30 GUEST_WIFI | `2001:db8:3:30::/64` |
| Manila | 40 DMZ_SERVERS | `2001:db8:3:40::/64` |
| Bangkok | 10 MGMT | `2001:db8:4:10::/64` |
| Bangkok | 20 LOGISTICS_SALES | `2001:db8:4:20::/64` |
| Bangkok | 30 GUEST_WIFI | `2001:db8:4:30::/64` |
| Bangkok | 40 DMZ_SERVERS | `2001:db8:4:40::/64` |

**WAN transit links use `/127`** (RFC 6164 — modern best practice for point-to-point links, the IPv6 equivalent of
using `/30` in IPv4 instead of wastefully handing out a full `/64` to a 2-device link):

| Link | Subnet | MY side | Remote side |
|---|---|---|---|
| MY ↔ Singapore | `2001:db8:ff::0/127` | `::0` | `::1` |
| MY ↔ Manila | `2001:db8:ff::2/127` | `::2` | `::3` |
| MY ↔ Bangkok | `2001:db8:ff::4/127` | `::4` | `::5` |

Every routed interface additionally gets its automatic **link-local** address (`fe80::/10`, generated via modified
EUI-64 from the interface MAC) regardless of the GUA assigned — link-local is what OSPFv3 neighbor relationships
actually form over, not the global address.

## Phase 2 — IPv6 routing plan

Static routes, not OSPFv3. OSPFv3 was configured and live-tested first, mirroring the OSPFv2 design exactly
(same router-IDs, area 0, per-interface enablement, `ipv6 unicast-routing` on every device) — it never formed a
single adjacency, on any link, on any device, despite config confirmed correct multiple independent ways
(`show ipv6 protocols`, `show ipv6 ospf interface brief`, a full interface bounce, and a full process rebuild on
the simplest possible isolated pair). OSPFv2 works perfectly on the exact same physical links, so this is a
confirmed Packet Tracer 9.0.0 OSPFv3 simulation limitation, not a configuration error — see
`../evidences/README.md`'s "IPv6 Cross-Site Routing" section for the full troubleshooting record and
verification screenshots.

`MY-KL-HQ-CORE` is the hub, directly connected to every other routing device, so it only needs one summarized
route per remote site (each site's 4 VLANs share a single `/48`, from the addressing plan above). Each spoke has
only one way out — back through the hub — so a single default route covers it, mirroring this project's own
IPv4 precedent (`PH-MNL-ROAS.cfg`/`TH-BKK-ROAS.cfg`'s "Phase 1 static default route", used before OSPFv2 was
proven working).

| Device | Static route(s) | Next hop |
|---|---|---|
| `MY-KL-HQ-CORE` | `2001:db8:3::/48` (Manila) | `2001:db8:ff::3` (`PH-MNL-ROAS`) |
| `MY-KL-HQ-CORE` | `2001:db8:4::/48` (Bangkok) | `2001:db8:ff::5` (`TH-BKK-ROAS`) |
| `SG-EDGE-GW` | `::/0` | `2001:db8:ff::0` (`MY-KL-HQ-CORE`) |
| `PH-MNL-ROAS` | `::/0` | `2001:db8:ff::2` (`MY-KL-HQ-CORE`) |
| `TH-BKK-ROAS` | `::/0` | `2001:db8:ff::4` (`MY-KL-HQ-CORE`) |

Verified end-to-end with a real cross-site IPv6 ping (`PH-MNL-ROAS` → `TH-BKK-ROAS`'s MGMT address), not just
`show ipv6 route` output.

## Phase 2 — OSPF Router ID & Loopback plan

Router IDs are set explicitly rather than left to auto-election (which would otherwise pick the highest IP on any
active loopback, or failing that the highest active physical interface IP — unpredictable and prone to changing
after a reload). Each OSPF-speaking device gets a dedicated `Loopback0` purely for this purpose: a loopback never
goes physically down the way a real interface can, so the Router ID (and later, management/SSH source address)
stays stable no matter what happens to physical links.

| Device | Loopback0 (Router ID) |
|---|---|
| `MY-KL-HQ-CORE` | `10.255.255.1/32` |
| `SG-EDGE-GW` | `10.255.255.2/32` |
| `PH-MNL-ROAS` | `10.255.255.3/32` |
| `TH-BKK-ROAS` | `10.255.255.4/32` |

## Not yet in this plan (tracked for later phases)

- **Floating static route / backup ISP failover** — intentionally out of scope. The topology has no second
  internet-facing link anywhere (`SG-EDGE-GW`'s `Gi0/0/1` is the only WAN-to-cloud path), so there's nothing for a
  floating static route to fail over to yet. Revisit if a second ISP/WAN link is ever added to the design.
- **HSRP/VRRP details beyond Malaysia HQ** (already configured on the core switch SVIs) — nothing further needed; Manila/Bangkok use single ROAS routers so there's no first-hop redundancy pair at those sites by design.

# Phase 1 & 2 — Regional On-Premises Network

CCNA 200-301-mapped on-premises network for the ASEAN regional topology: Malaysia HQ (hub), Singapore (WAN/cloud
edge), Manila and Bangkok (branch sites). Built and verified in Cisco Packet Tracer 9.0.0.

**Phase 1 (Basic Connectivity):** VLANs, trunking, EtherChannel, HSRP, WAN uplinks, port security.
**Phase 2 (Dynamic Routing & IPv6):** OSPFv2 Area 0, Router ID/loopback design, DR/BDR election, management SSH,
IPv6 dual-stack addressing and cross-site routing.

## Highlights

Verification here didn't stop at "the config looks right" — every claim below was confirmed live, and a few
turned into real findings along the way:

- **OSPFv3 confirmed broken on this platform, not just abandoned.** Configured and live-tested first, mirroring
  the working OSPFv2 design exactly — verified via `show ipv6 protocols`, a full interface bounce, and a
  complete process rebuild on the simplest possible isolated link. Never formed a single adjacency. Pivoted to
  static IPv6 routing with full end-to-end cross-site proof instead of quietly giving up. See
  [`evidences/README.md`](evidences/README.md#ipv6-cross-site-routing).
- **`show spanning-tree summary` caught fabricating its own numbers.** The command reported dozens of ports
  `Blocking` and almost none `Forwarding` — cross-checked against `show spanning-tree`'s detailed per-VLAN output
  on the same device, run back to back, which showed every interface actually `Forwarding` with zero blocking.
  Confirmed as a platform display bug, not a network problem. See
  [`evidences/README.md`](evidences/README.md#hsrp--spanning-tree).
- **LACP EtherChannel stuck stand-alone despite byte-for-byte matching config on both switches.** A plain
  interface bounce didn't fix it; a full `no channel-group`/`no channel-protocol lacp`/re-add did. See
  [`evidences/README.md`](evidences/README.md#etherchannel).
- **`show lacp` and `passive-interface` under `ipv6 router ospf` both confirmed absent/broken on this Packet
  Tracer build** — verified directly (paging the full command tree, isolating the exact failing syntax) rather
  than assumed from a single failed attempt. See
  [`evidences/platform-limitations/`](evidences/platform-limitations/).

## Production Considerations

This project is intentionally lab-scoped. A few design choices here are correct *for a Packet Tracer lab* but
would need revisiting before carrying real production traffic:

- **Single-core HSRP has no failover peer.** `MY-KL-HQ-CORE` is the only Layer 3 device at HQ — HSRP is
  configured and correctly evidenced, but there's no second physical core switch to actually fail over to. A
  production deployment would need a real active/standby core pair.
- **Wireless was designed for but never deployed.** `Gi1/0/10` is provisioned as a trunk to a Cisco WLC, but no
  WLC/APs were ever built (a project-scope decision, not an oversight). A real deployment needs the WLC, an AP
  site survey, and dynamic wireless VLANs actually stood up.
- **Static IPv6 routing is a simulator workaround, not the production recommendation.** OSPFv3 never forming
  adjacencies is a confirmed Packet Tracer limitation, not a design choice — see the Highlights above. On real
  hardware, OSPFv3 (or another IGP) should be revisited, since static routes don't scale as cleanly as new sites
  or links get added.
- **No redundant WAN circuit anywhere.** Every site — including `SG-EDGE-GW`, the AWS on-ramp — has exactly one
  upstream link. Production would want at least a backup circuit with floating-static or dynamic failover.
- **Authentication is local-only, no centralized AAA.** Every device uses local `username`/`enable secret`
  accounts. Production should integrate RADIUS/TACACS+ (e.g. Cisco ISE) instead of per-device local credentials.
- **`MY-KL-HQ-DIST` is explicitly exempted from Phase 3 hardening** (no SSH/ACL/port-security), since it only
  exists to validate LACP EtherChannel. A real distribution switch carrying production traffic wouldn't get that
  exemption.

## Devices

| Device | Role | Platform |
|---|---|---|
| `MY-KL-HQ-CORE` | Core/distribution switch (L3, HSRP, EtherChannel) | Catalyst 3650-24PS |
| `MY-KL-HQ-DIST` | Distribution switch — LACP EtherChannel peer for `MY-KL-HQ-CORE` | Catalyst 3650-24PS |
| `SG-EDGE-GW` | WAN edge / cloud on-ramp router | ISR 4331 |
| `PH-MNL-ROAS` | Manila router-on-a-stick | ISR 4321 |
| `PH-MNL-ACC` | Manila access switch | Catalyst 2960-24TT |
| `TH-BKK-ROAS` | Bangkok router-on-a-stick | ISR 4321 |
| `TH-BKK-ACC` | Bangkok access switch | Catalyst 2960-24TT |
| `MY-KL-DMZ-SRV` | Core services server (TFTP / Syslog), added mid-Phase 3 | Packet Tracer Server device |

Full addressing plan and device rationale: [`topologies/asean-network-topology.md`](topologies/asean-network-topology.md).

## In this folder

- [`switching/`](switching/) — access/core/distribution switch configs
- [`router-configs/`](router-configs/) — WAN/ROAS router configs
- [`topologies/`](topologies/) — topology diagram, IPv4/IPv6 addressing plan, Packet Tracer build guide
- [`evidences/`](evidences/) — live `show`-command screenshots proving every config actually works, not just
  written and assumed correct

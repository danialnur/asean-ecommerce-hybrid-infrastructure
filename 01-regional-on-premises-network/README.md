# Phase 1 & 2 — Regional On-Premises Network

CCNA 200-301-mapped on-premises network for the ASEAN regional topology: Malaysia HQ (hub), Singapore (WAN/cloud
edge), Manila and Bangkok (branch sites). Built and verified in Cisco Packet Tracer 9.0.0.

**Phase 1 (Basic Connectivity):** VLANs, trunking, EtherChannel, HSRP, port security, SSH.
**Phase 2 (Dynamic Routing & IPv6):** OSPFv2 Area 0, Router ID/loopback design, DR/BDR election, IPv6 dual-stack
addressing and cross-site routing.

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

Full addressing plan and device rationale: [`topologies/asean-network-topology.md`](topologies/asean-network-topology.md).

## In this folder

- [`switching/`](switching/) — access/core/distribution switch configs
- [`router-configs/`](router-configs/) — WAN/ROAS router configs
- [`topologies/`](topologies/) — topology diagram, IPv4/IPv6 addressing plan, Packet Tracer build guide
- [`evidences/`](evidences/) — live `show`-command screenshots proving every config actually works, not just
  written and assumed correct

Phase 1 & 2 certification-guide PDFs exist locally in a gitignored `docs/` folder — not published here.

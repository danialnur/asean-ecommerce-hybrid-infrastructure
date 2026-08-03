# Phase 1 & 2 — Regional On-Premises Network

CCNA 200-301-mapped on-premises network for the ASEAN regional topology: Malaysia HQ (hub), Singapore (WAN/cloud
edge), Manila and Bangkok (branch sites). Built and verified in Cisco Packet Tracer 9.0.0.

**Phase 1 (Basic Connectivity):** VLANs, trunking, EtherChannel, HSRP, WAN uplinks, port security.
**Phase 2 (Dynamic Routing & IPv6):** OSPFv2 Area 0, Router ID/loopback design, DR/BDR election, management SSH,
IPv6 dual-stack addressing and cross-site routing.

Every claim above was verified live, not just written and assumed correct — including real findings along the
way: OSPFv3 [confirmed broken on this platform, not abandoned](evidences/README.md#ipv6-cross-site-routing), a
[`show spanning-tree summary` display bug](evidences/README.md#hsrp--spanning-tree) caught by cross-checking
against a different command, an [LACP EtherChannel stuck stand-alone](evidences/README.md#etherchannel) despite
byte-for-byte matching config, and [confirmed Packet Tracer command gaps](evidences/platform-limitations/). Full
write-up: [`evidences/README.md`](evidences/README.md).

Full addressing plan, device inventory, and lab-vs-production tradeoffs:
[`topologies/asean-network-topology.md`](topologies/asean-network-topology.md).

## In this folder

- [`switching/`](switching/) — access/core/distribution switch configs
- [`router-configs/`](router-configs/) — WAN/ROAS router configs
- [`topologies/`](topologies/) — topology diagram, IPv4/IPv6 addressing plan, Packet Tracer build guide
- [`evidences/`](evidences/) — live `show`-command screenshots proving every config actually works, not just
  written and assumed correct

# Phase 1 & 2 — Verification Screenshots

Live `show` command output and topology view from Packet Tracer, captured as evidence that the switching/routing
configs in `../switching/` and `../router-configs/` behave as documented — not just written and assumed correct.
(Converted from the original `screenshots.docx` so it renders directly on GitHub instead of requiring a download.)

- [`phase-1-basic-connectivity/`](phase-1-basic-connectivity/) — VLANs, trunking, EtherChannel, HSRP/STP, port
  security, SSH
- [`phase-2-dynamic-routing-ipv6/`](phase-2-dynamic-routing-ipv6/) — OSPF adjacencies/routes, IPv4 reachability,
  IPv6 addressing and routing

Ordered start to finish, from the physical topology through to the last thing actually built and verified
(IPv6 cross-site routing) — file numbers in `./phase-1-basic-connectivity/` and
`./phase-2-dynamic-routing-ipv6/` follow this same order.

## Topology Overview

Full Packet Tracer topology view — SG-EDGE-GW (ISR4331) uplinked through MY-KL-HQ-CORE (3650-24PS) to the
Thailand (ISR4321 ROAS + 2960-24TT access) and Philippines (ISR4321 ROAS + 2960-24TT access) branches, with
MY-KL-HQ-DIST (3650-24PS) hanging off MY-KL-HQ-CORE as its LACP EtherChannel peer.

<p align="center">
  <img src="./phase-1-basic-connectivity/01-topology-overview.png" alt="Topology overview"><br>
  <sub>Full topology view</sub>
</p>

## VLANs

<p align="center">
  <img src="./phase-1-basic-connectivity/02-vlan-brief-my-kl-hq-core.png" alt="MY-KL-HQ-CORE sh vlan brief"><br>
  <sub><code>MY-KL-HQ-CORE# sh vlan brief</code></sub>
</p>

<p align="center">
  <img src="./phase-1-basic-connectivity/03-vlan-brief-ph-mnl-acc.png" alt="PH-MNL-ACC sh vlan brief"><br>
  <sub><code>PH-MNL-ACC# sh vlan brief</code></sub>
</p>

<p align="center">
  <img src="./phase-1-basic-connectivity/04-vlan-brief-th-bkk-acc.png" alt="TH-BKK-ACC sh vlan brief"><br>
  <sub><code>TH-BKK-ACC# sh vlan brief</code></sub>
</p>

## Trunking

<p align="center">
  <img src="./phase-1-basic-connectivity/05-interfaces-trunk-ph-mnl-acc.png" alt="PH-MNL-ACC sh interfaces trunk"><br>
  <sub><code>PH-MNL-ACC# sh interfaces trunk</code></sub>
</p>

<p align="center">
  <img src="./phase-1-basic-connectivity/06-interfaces-trunk-th-bkk-acc.png" alt="TH-BKK-ACC sh interfaces trunk"><br>
  <sub><code>TH-BKK-ACC# sh interfaces trunk</code></sub>
</p>

## EtherChannel

`MY-KL-HQ-CORE`'s LACP EtherChannel (`Port-channel1`, `Gi1/0/1-2`) existed from Phase 1 but had no peer to bundle
with until `MY-KL-HQ-DIST` was added specifically to verify it (see `../topologies/asean-network-topology.md`'s
device inventory note and `../switching/MY-KL-HQ-DIST.cfg`). Live testing caught a real issue: the first LACP
negotiation attempt left both member ports stand-alone (`show etherchannel summary` flag `I`, not `P`) despite
byte-for-byte matching config on both switches. Confirmed this wasn't a config error by temporarily testing
static `channel-group 1 mode on`, which bundled immediately — then removing and re-adding LACP channel-group
membership on both switches (`no channel-group 1` / `no channel-protocol lacp` / re-add) reset the LACP state
machine and brought the bundle up cleanly under real LACP. The screenshots below are from that final, working
state.

<p align="center">
  <img src="./phase-1-basic-connectivity/07-etherchannel-summary-my-kl-hq-core.png" alt="MY-KL-HQ-CORE etherchannel summary"><br>
  <sub><code>MY-KL-HQ-CORE# sh etherchannel summary</code> — <code>Po1(SU)</code>, both members <code>(P)</code>, protocol LACP</sub>
</p>

<p align="center">
  <img src="./phase-1-basic-connectivity/08-interfaces-trunk-my-kl-hq-core.png" alt="MY-KL-HQ-CORE interfaces trunk"><br>
  <sub><code>MY-KL-HQ-CORE# sh interfaces trunk</code> — <code>Po1</code> trunking, native VLAN 99, all 5 VLANs allowed</sub>
</p>

## HSRP & Spanning Tree

<p align="center">
  <img src="./phase-1-basic-connectivity/09-standby-brief-hsrp-my-kl-hq-core.png" alt="MY-KL-HQ-CORE sh standby brief"><br>
  <sub><code>MY-KL-HQ-CORE# sh standby brief</code> — all 4 HSRP groups active, no peer (single-core design)</sub>
</p>

<p align="center">
  <img src="./phase-1-basic-connectivity/10-spanning-tree-summary-my-kl-hq-core.png" alt="MY-KL-HQ-CORE sh spanning-tree summary"><br>
  <sub><code>MY-KL-HQ-CORE# sh spanning-tree summary</code> — rapid-PVST+, PortFast/BPDU Guard enabled</sub>
</p>

`PH-MNL-ACC# sh spanning-tree summary` and `TH-BKK-ACC# sh spanning-tree summary` both show `Root bridge for:
MGMT LOGISTICS_SALES GUEST_WIFI DMZ_SERVERS NATIVE`, i.e. each access switch is root of its *own* domain, not a
subordinate of `MY-KL-HQ-CORE`. That's correct, not a misconfiguration: each access switch sits behind its
site's ROAS *router* (`PH-MNL-ROAS`/`TH-BKK-ROAS`), and a router is a Layer 3 boundary that doesn't forward
BPDUs - there's no Layer 2 path back to `MY-KL-HQ-CORE`'s spanning-tree domain at all, so each access switch is
necessarily isolated in its own local instance. What actually matters is confirmed on both: 0 blocking ports,
all 6 VLANs forwarding cleanly.

<p align="center">
  <img src="./phase-1-basic-connectivity/11-spanning-tree-summary-ph-mnl-acc.png" alt="PH-MNL-ACC sh spanning-tree summary"><br>
  <sub><code>PH-MNL-ACC# sh spanning-tree summary</code></sub>
</p>

<p align="center">
  <img src="./phase-1-basic-connectivity/12-spanning-tree-summary-th-bkk-acc.png" alt="TH-BKK-ACC sh spanning-tree summary"><br>
  <sub><code>TH-BKK-ACC# sh spanning-tree summary</code></sub>
</p>

## Port Security

<p align="center">
  <img src="./phase-1-basic-connectivity/13-port-security-my-kl-hq-core.png" alt="MY-KL-HQ-CORE port security"><br>
  <sub><code>MY-KL-HQ-CORE# sh port-security int g1/0/11</code></sub>
</p>

<p align="center">
  <img src="./phase-1-basic-connectivity/14-port-security-ph-mnl-acc.png" alt="PH-MNL-ACC port security"><br>
  <sub><code>PH-MNL-ACC# sh port-security int fa0/1</code></sub>
</p>

<p align="center">
  <img src="./phase-1-basic-connectivity/15-port-security-th-bkk-acc.png" alt="TH-BKK-ACC port security"><br>
  <sub><code>TH-BKK-ACC# sh port-security int fa0/1</code></sub>
</p>

## Management SSH

<p align="center">
  <img src="./phase-1-basic-connectivity/16-ssh-th-bkk-acc-to-ph-mnl-acc.png" alt="SSH TH-BKK-ACC to PH-MNL-ACC"><br>
  <sub><code>TH-BKK-ACC# ssh -l asean.admin 10.10.110.2</code> — cross-site SSH session, TH-BKK-ACC to PH-MNL-ACC</sub>
</p>

## OSPF Adjacencies

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/01-ospf-neighbor-my-kl-hq-core.png" alt="MY-KL-HQ-CORE OSPF neighbors"><br>
  <sub><code>MY-KL-HQ-CORE# sh ip ospf neigh</code></sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/02-ospf-neighbor-sg-edge-gw.png" alt="SG-EDGE-GW OSPF neighbors"><br>
  <sub><code>SG-EDGE-GW# sh ip ospf neigh</code></sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/03-ospf-neighbor-ph-mnl-roas.png" alt="PH-MNL-ROAS OSPF neighbors"><br>
  <sub><code>PH-MNL-ROAS# sh ip ospf neigh</code></sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/04-ospf-neighbor-th-bkk-roas.png" alt="TH-BKK-ROAS OSPF neighbors"><br>
  <sub><code>TH-BKK-ROAS# sh ip ospf neigh</code></sub>
</p>

## OSPF Routing Table

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/05-ip-route-ospf-ph-mnl-roas.png" alt="PH-MNL-ROAS OSPF routes"><br>
  <sub><code>PH-MNL-ROAS# sh ip route ospf</code></sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/06-ip-route-ospf-th-bkk-roas.png" alt="TH-BKK-ROAS OSPF routes"><br>
  <sub><code>TH-BKK-ROAS# sh ip route ospf</code></sub>
</p>

`MY-KL-HQ-CORE# sh ip route ospf` is the hub's own view, showing OSPF routes to both branches (Manila
`10.10.110.0–113.0`, Bangkok `10.10.120.0–123.0`) simultaneously, unlike the branch-side views above which only
see routes back toward HQ and each other. (The `26 subnets` in the header reflects every `10.0.0.0/8` subnet
known to the full routing table, not just the 11 OSPF-learned routes filtered and listed below — a normal IOS
quirk, not a truncated capture.)

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/07-ip-route-ospf-my-kl-hq-core.png" alt="MY-KL-HQ-CORE OSPF routes"><br>
  <sub><code>MY-KL-HQ-CORE# sh ip route ospf</code></sub>
</p>

## End-to-End Reachability

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/08-ping-ph-mnl-acc-to-vlan120.png" alt="Ping to 10.10.120.1"><br>
  <sub><code>PH-MNL-ACC# ping 10.10.120.1</code> — 100% success, cross-VLAN via ROAS</sub>
</p>

`PH-MNL-ACC# ping 10.10.110.1` below is 100% success, but it's really PH-MNL-ACC reaching its own local default
gateway (PH-MNL-ROAS's MGMT sub-interface) rather than a cross-site test — the genuinely cross-site counterpart
follows it.

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/09-ping-ph-mnl-acc-to-vlan110.png" alt="Ping to 10.10.110.1"><br>
  <sub><code>PH-MNL-ACC# ping 10.10.110.1</code></sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/10-ping-th-bkk-acc-to-ph-mnl-roas.png" alt="Ping from TH-BKK-ACC to PH-MNL-ROAS"><br>
  <sub><code>TH-BKK-ACC# ping 10.10.110.1</code> — genuinely cross-site: Bangkok's access switch reaching Manila's ROAS router, routed via OSPF through MY-KL-HQ-CORE</sub>
</p>

## IPv6 Dual-Stack

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/11-ipv6-int-brief-ph-mnl-roas.png" alt="PH-MNL-ROAS IPv6 interfaces"><br>
  <sub><code>PH-MNL-ROAS# sh ipv6 int brief</code></sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/12-ipv6-int-brief-th-bkk-roas.png" alt="TH-BKK-ROAS IPv6 interfaces"><br>
  <sub><code>TH-BKK-ROAS# sh ipv6 int brief</code></sub>
</p>

`MY-KL-HQ-CORE# sh ipv6 int brief` was captured in two parts below, output paginated past `--More--` at
`Gi1/0/21`. No `Vlan99` entry is expected — VLAN 99 is native-only and was never given its own SVI, consistent
with the HSRP screenshot above (only VLANs 10/20/30/40 have HSRP groups).

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/13-ipv6-int-brief-my-kl-hq-core-part1.png" alt="MY-KL-HQ-CORE IPv6 interfaces, part 1"><br>
  <sub><code>MY-KL-HQ-CORE# sh ipv6 int brief</code> — part 1</sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/14-ipv6-int-brief-my-kl-hq-core-part2.png" alt="MY-KL-HQ-CORE IPv6 interfaces, part 2"><br>
  <sub><code>MY-KL-HQ-CORE# sh ipv6 int brief</code> — part 2</sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/15-ipv6-int-brief-sg-edge-gw.png" alt="SG-EDGE-GW IPv6 interfaces"><br>
  <sub><code>SG-EDGE-GW# sh ipv6 int brief</code></sub>
</p>

## IPv6 Cross-Site Routing

The screenshots above only prove IPv6 *addressing* exists on every device — none of it proves IPv6 can actually
*route* between sites. Closing that gap turned into a real finding.

**OSPFv3 was configured and live-tested first**, mirroring the existing OSPFv2 design exactly: same router-IDs
(`10.255.255.1-4`), same area 0, `ipv6 unicast-routing` confirmed present on every device. It never worked.
`show ipv6 ospf interface brief` showed every interface correctly registered under area 0 (config confirmed
correct multiple ways: `show ipv6 protocols`, per-interface state, a full interface bounce, and a full removal
and rebuild of the OSPFv3 process) — yet `Nbrs F/C` stayed `0/0` everywhere, including the simplest possible
case: a single directly-connected pair (`MY-KL-HQ-CORE` ↔ `SG-EDGE-GW`) with a freshly rebuilt process on both
ends. OSPFv2 forms adjacencies perfectly on these exact same physical links. This is a confirmed Packet Tracer
9.0.0 OSPFv3 simulation limitation, not a configuration error — joining the other confirmed platform gaps this
project has documented (SNMPv3, spanning-tree extend/loopguard, the SVI `ip access-group` bug, no real-NIC
bridge, and `show lacp`/`passive-interface` command-parsing gaps found earlier in this same evidence pass).

**Static routes replaced it**, mirroring a pattern this project's own IPv4 design already used (see the "Phase 1
static default route" comments in `PH-MNL-ROAS.cfg`/`TH-BKK-ROAS.cfg`'s OSPF sections, from before OSPFv2 was
proven working). `MY-KL-HQ-CORE` is the hub, so it only needs one summarized route per remote site — every site's
4 VLANs share a single `/48`. Each spoke (`SG-EDGE-GW`, `PH-MNL-ROAS`, `TH-BKK-ROAS`) just needs a single default
route back to the hub, its only way out. See the matching `ipv6 route` comments in each device's `.cfg` file.

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/16-ipv6-route-my-kl-hq-core.png" alt="MY-KL-HQ-CORE IPv6 routing table"><br>
  <sub><code>MY-KL-HQ-CORE# sh ipv6 route</code> — two static routes, one summarized <code>/48</code> per remote site</sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/17-ipv6-route-sg-edge-gw.png" alt="SG-EDGE-GW IPv6 routing table"><br>
  <sub><code>SG-EDGE-GW# sh ipv6 route</code> — single default route back to the hub</sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/18-ipv6-route-ph-mnl-roas.png" alt="PH-MNL-ROAS IPv6 routing table"><br>
  <sub><code>PH-MNL-ROAS# sh ipv6 route</code> — single default route back to the hub</sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/19-ipv6-route-th-bkk-roas.png" alt="TH-BKK-ROAS IPv6 routing table"><br>
  <sub><code>TH-BKK-ROAS# sh ipv6 route</code> — single default route back to the hub</sub>
</p>

This is the real end-to-end proof: IPv6 dual-stack now means addressing *and* routing, not just addressing.

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/20-ping-ipv6-ph-mnl-roas-to-th-bkk-roas.png" alt="Cross-site IPv6 ping, PH-MNL-ROAS to TH-BKK-ROAS"><br>
  <sub><code>PH-MNL-ROAS# ping 2001:DB8:4:10:250:FFF:FEC1:DD01</code> — genuinely cross-site (Manila to Bangkok's MGMT address), 100% success</sub>
</p>

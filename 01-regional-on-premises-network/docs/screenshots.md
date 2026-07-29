# Phase 1 & 2 — Verification Screenshots

Live `show` command output and topology view from Packet Tracer, captured as evidence that the switching/routing
configs in `../switching/` and `../router-configs/` behave as documented — not just written and assumed correct.
(Converted from the original `screenshots.docx` so it renders directly on GitHub instead of requiring a download.)

## VLANs

**`MY-KL-HQ-CORE# sh vlan brief`**
![MY-KL-HQ-CORE sh vlan brief](../evidences/01-vlan-brief-my-kl-hq-core.png)

**`PH-MNL-ACC# sh vlan brief`**
![PH-MNL-ACC sh vlan brief](../evidences/02-vlan-brief-ph-mnl-acc.png)

**`TH-BKK-ACC# sh vlan brief`**
![TH-BKK-ACC sh vlan brief](../evidences/03-vlan-brief-th-bkk-acc.png)

## HSRP & Spanning Tree

**`MY-KL-HQ-CORE# sh standby brief`** — all 4 HSRP groups active, no peer (single-core design)
![MY-KL-HQ-CORE sh standby brief](../evidences/04-standby-brief-hsrp-my-kl-hq-core.png)

**`MY-KL-HQ-CORE# sh spanning-tree summary`** — rapid-PVST+, PortFast/BPDU Guard enabled
![MY-KL-HQ-CORE sh spanning-tree summary](../evidences/05-spanning-tree-summary-my-kl-hq-core.png)

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

**`MY-KL-HQ-CORE# sh etherchannel summary`** — `Po1(SU)`, both members `(P)`, protocol LACP
![MY-KL-HQ-CORE etherchannel summary](../evidences/23-etherchannel-summary-my-kl-hq-core.png)

**`MY-KL-HQ-CORE# sh interfaces trunk`** — `Po1` trunking, native VLAN 99, all 5 VLANs allowed
![MY-KL-HQ-CORE interfaces trunk](../evidences/24-interfaces-trunk-my-kl-hq-core.png)

## Trunking

**`PH-MNL-ACC# sh interfaces trunk`**
![PH-MNL-ACC sh interfaces trunk](../evidences/06-interfaces-trunk-ph-mnl-acc.png)

**`TH-BKK-ACC# sh interfaces trunk`**
![TH-BKK-ACC sh interfaces trunk](../evidences/07-interfaces-trunk-th-bkk-acc.png)

## Port Security

**`MY-KL-HQ-CORE# sh port-security int g1/0/11`**
![MY-KL-HQ-CORE port security](../evidences/08-port-security-my-kl-hq-core.png)

**`PH-MNL-ACC# sh port-security int fa0/1`**
![PH-MNL-ACC port security](../evidences/09-port-security-ph-mnl-acc.png)

**`TH-BKK-ACC# sh port-security int fa0/1`**
![TH-BKK-ACC port security](../evidences/10-port-security-th-bkk-acc.png)

## Management SSH

**`TH-BKK-ACC# ssh -l asean.admin 10.10.110.2`** — cross-site SSH session, TH-BKK-ACC to PH-MNL-ACC
![SSH TH-BKK-ACC to PH-MNL-ACC](../evidences/11-ssh-th-bkk-acc-to-ph-mnl-acc.png)

## OSPF Adjacencies

**`MY-KL-HQ-CORE# sh ip ospf neigh`**
![MY-KL-HQ-CORE OSPF neighbors](../evidences/12-ospf-neighbor-my-kl-hq-core.png)

**`SG-EDGE-GW# sh ip ospf neigh`**
![SG-EDGE-GW OSPF neighbors](../evidences/13-ospf-neighbor-sg-edge-gw.png)

**`PH-MNL-ROAS# sh ip ospf neigh`**
![PH-MNL-ROAS OSPF neighbors](../evidences/14-ospf-neighbor-ph-mnl-roas.png)

**`TH-BKK-ROAS# sh ip ospf neigh`**
![TH-BKK-ROAS OSPF neighbors](../evidences/15-ospf-neighbor-th-bkk-roas.png)

## End-to-End Reachability

**`PH-MNL-ACC# ping 10.10.120.1`** — 100% success, cross-VLAN via ROAS
![Ping to 10.10.120.1](../evidences/16-ping-ph-mnl-acc-to-vlan120.png)

**`PH-MNL-ACC# ping 10.10.110.1`** — 100% success
![Ping to 10.10.110.1](../evidences/17-ping-ph-mnl-acc-to-vlan110.png)

## OSPF Routing Table

**`PH-MNL-ROAS# sh ip route ospf`**
![PH-MNL-ROAS OSPF routes](../evidences/18-ip-route-ospf-ph-mnl-roas.png)

**`TH-BKK-ROAS# sh ip route ospf`**
![TH-BKK-ROAS OSPF routes](../evidences/19-ip-route-ospf-th-bkk-roas.png)

**`MY-KL-HQ-CORE# sh ip route ospf`** — the hub's own view, showing OSPF routes to both branches (Manila
`10.10.110.0–113.0`, Bangkok `10.10.120.0–123.0`) simultaneously, unlike the branch-side views above which only
see routes back toward HQ and each other. (The `26 subnets` in the header reflects every `10.0.0.0/8` subnet
known to the full routing table, not just the 11 OSPF-learned routes filtered and listed below — a normal IOS
quirk, not a truncated capture.)
![MY-KL-HQ-CORE OSPF routes](../evidences/27-ip-route-ospf-my-kl-hq-core.png)

## IPv6 Dual-Stack

**`PH-MNL-ROAS# sh ipv6 int brief`**
![PH-MNL-ROAS IPv6 interfaces](../evidences/20-ipv6-int-brief-ph-mnl-roas.png)

**`TH-BKK-ROAS# sh ipv6 int brief`**
![TH-BKK-ROAS IPv6 interfaces](../evidences/21-ipv6-int-brief-th-bkk-roas.png)

**`MY-KL-HQ-CORE# sh ipv6 int brief`** — captured in two parts, output paginated past `--More--` at `Gi1/0/21`.
No `Vlan99` entry is expected — VLAN 99 is native-only and was never given its own SVI, consistent with the HSRP
screenshot above (only VLANs 10/20/30/40 have HSRP groups).
![MY-KL-HQ-CORE IPv6 interfaces, part 1](../evidences/25-ipv6-int-brief-my-kl-hq-core-part1.png)
![MY-KL-HQ-CORE IPv6 interfaces, part 2](../evidences/26-ipv6-int-brief-my-kl-hq-core-part2.png)

**`SG-EDGE-GW# sh ipv6 int brief`**
![SG-EDGE-GW IPv6 interfaces](../evidences/28-ipv6-int-brief-sg-edge-gw.png)

## Topology Overview

Full Packet Tracer topology view — SG-EDGE-GW (ISR4331) uplinked through MY-KL-HQ-CORE (3650-24PS) to the
Thailand (ISR4321 ROAS + 2960-24TT access) and Philippines (ISR4321 ROAS + 2960-24TT access) branches.
![Topology overview](../evidences/22-topology-overview.png)

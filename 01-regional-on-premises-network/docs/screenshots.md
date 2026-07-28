# Phase 1 & 2 — Verification Screenshots

Live `show` command output and topology view from Packet Tracer, captured as evidence that the switching/routing
configs in `../switching/` and `../router-configs/` behave as documented — not just written and assumed correct.
(Converted from the original `screenshots.docx` so it renders directly on GitHub instead of requiring a download.)

## VLANs

**`MY-KL-HQ-CORE# sh vlan brief`**
![MY-KL-HQ-CORE sh vlan brief](screenshots/01-vlan-brief-my-kl-hq-core.png)

**`PH-MNL-ACC# sh vlan brief`**
![PH-MNL-ACC sh vlan brief](screenshots/02-vlan-brief-ph-mnl-acc.png)

**`TH-BKK-ACC# sh vlan brief`**
![TH-BKK-ACC sh vlan brief](screenshots/03-vlan-brief-th-bkk-acc.png)

## HSRP & Spanning Tree

**`MY-KL-HQ-CORE# sh standby brief`** — all 4 HSRP groups active, no peer (single-core design)
![MY-KL-HQ-CORE sh standby brief](screenshots/04-standby-brief-hsrp-my-kl-hq-core.png)

**`MY-KL-HQ-CORE# sh spanning-tree summary`** — rapid-PVST+, PortFast/BPDU Guard enabled
![MY-KL-HQ-CORE sh spanning-tree summary](screenshots/05-spanning-tree-summary-my-kl-hq-core.png)

## Trunking

**`PH-MNL-ACC# sh interfaces trunk`**
![PH-MNL-ACC sh interfaces trunk](screenshots/06-interfaces-trunk-ph-mnl-acc.png)

**`TH-BKK-ACC# sh interfaces trunk`**
![TH-BKK-ACC sh interfaces trunk](screenshots/07-interfaces-trunk-th-bkk-acc.png)

## Port Security

**`MY-KL-HQ-CORE# sh port-security int g1/0/11`**
![MY-KL-HQ-CORE port security](screenshots/08-port-security-my-kl-hq-core.png)

**`PH-MNL-ACC# sh port-security int fa0/1`**
![PH-MNL-ACC port security](screenshots/09-port-security-ph-mnl-acc.png)

**`TH-BKK-ACC# sh port-security int fa0/1`**
![TH-BKK-ACC port security](screenshots/10-port-security-th-bkk-acc.png)

## Management SSH

**`TH-BKK-ACC# ssh -l asean.admin 10.10.110.2`** — cross-site SSH session, TH-BKK-ACC to PH-MNL-ACC
![SSH TH-BKK-ACC to PH-MNL-ACC](screenshots/11-ssh-th-bkk-acc-to-ph-mnl-acc.png)

## OSPF Adjacencies

**`MY-KL-HQ-CORE# sh ip ospf neigh`**
![MY-KL-HQ-CORE OSPF neighbors](screenshots/12-ospf-neighbor-my-kl-hq-core.png)

**`SG-EDGE-GW# sh ip ospf neigh`**
![SG-EDGE-GW OSPF neighbors](screenshots/13-ospf-neighbor-sg-edge-gw.png)

**`PH-MNL-ROAS# sh ip ospf neigh`**
![PH-MNL-ROAS OSPF neighbors](screenshots/14-ospf-neighbor-ph-mnl-roas.png)

**`TH-BKK-ROAS# sh ip ospf neigh`**
![TH-BKK-ROAS OSPF neighbors](screenshots/15-ospf-neighbor-th-bkk-roas.png)

## End-to-End Reachability

**`PH-MNL-ACC# ping 10.10.120.1`** — 100% success, cross-VLAN via ROAS
![Ping to 10.10.120.1](screenshots/16-ping-ph-mnl-acc-to-vlan120.png)

**`PH-MNL-ACC# ping 10.10.110.1`** — 100% success
![Ping to 10.10.110.1](screenshots/17-ping-ph-mnl-acc-to-vlan110.png)

## OSPF Routing Table

**`PH-MNL-ROAS# sh ip route ospf`**
![PH-MNL-ROAS OSPF routes](screenshots/18-ip-route-ospf-ph-mnl-roas.png)

**`TH-BKK-ROAS# sh ip route ospf`**
![TH-BKK-ROAS OSPF routes](screenshots/19-ip-route-ospf-th-bkk-roas.png)

## IPv6 Dual-Stack

**`PH-MNL-ROAS# sh ipv6 int brief`**
![PH-MNL-ROAS IPv6 interfaces](screenshots/20-ipv6-int-brief-ph-mnl-roas.png)

**`TH-BKK-ROAS# sh ipv6 int brief`**
![TH-BKK-ROAS IPv6 interfaces](screenshots/21-ipv6-int-brief-th-bkk-roas.png)

## Topology Overview

Full Packet Tracer topology view — SG-EDGE-GW (ISR4331) uplinked through MY-KL-HQ-CORE (3650-24PS) to the
Thailand (ISR4321 ROAS + 2960-24TT access) and Philippines (ISR4321 ROAS + 2960-24TT access) branches.
![Topology overview](screenshots/22-topology-overview.png)

# Phase 1 & 2 — Verification Screenshots

Live `show` command output and topology view from Packet Tracer, captured as evidence that the switching/routing
configs in `../switching/` and `../router-configs/` behave as documented — not just written and assumed correct.
(Converted from the original `screenshots.docx` so it renders directly on GitHub instead of requiring a download.)

- [`phase-1-basic-connectivity/`](phase-1-basic-connectivity/) — VLANs, trunking, EtherChannel, HSRP/STP, WAN
  uplinks, port security
- [`phase-2-dynamic-routing-ipv6/`](phase-2-dynamic-routing-ipv6/) — OSPF adjacencies/routes, IPv4 reachability,
  management SSH (cross-site, genuinely depends on this phase's routing), IPv6 addressing and routing
- [`platform-limitations/`](platform-limitations/) — screenshot proof of three confirmed Packet Tracer 9.0.0
  limitations (`show lacp` missing, `passive-interface` rejected under `ipv6 router ospf`, `show spanning-tree
  summary`'s per-VLAN port-state counts unreliable)

Ordered start to finish, from the physical topology through to the last thing actually built and verified
(IPv6 cross-site routing) — file numbers in `./phase-1-basic-connectivity/` and
`./phase-2-dynamic-routing-ipv6/` follow this same order.

## Topology Overview

Full Packet Tracer topology view — SG-EDGE-GW (ISR4331) uplinked through MY-KL-HQ-CORE (3650-24PS) to the
Thailand (ISR4321 ROAS + 2960-24TT access) and Philippines (ISR4321 ROAS + 2960-24TT access) branches, with
MY-KL-HQ-DIST (3650-24PS) hanging off MY-KL-HQ-CORE as its LACP EtherChannel peer, and MY-KL-DMZ-SRV (Server-PT)
on `Gi1/0/21` — recaptured after the DMZ server was added mid-Phase 3, so this reflects the full 8-device
topology as it stands today, not the original 7-device Phase 1 snapshot.

<p align="center">
  <img src="./phase-1-basic-connectivity/01-topology-overview.png" alt="Topology overview"><br>
  <sub>Full topology view, including MY-KL-DMZ-SRV</sub>
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
  <sub><code>MY-KL-HQ-CORE# sh spanning-tree summary</code> — rapid-PVST+, PortFast/BPDU Guard enabled, root bridge for all 5 VLANs</sub>
</p>

**Recaptured and confirmed root-bridge status is correct** (`Root bridge for: MGMT LOGISTICS_SALES GUEST_WIFI
DMZ_SERVERS NATIVE`, matching `MY-KL-HQ-CORE.cfg`'s `spanning-tree vlan 10,20,30,40,99 root primary`) — the
original capture's blank root-bridge line was indeed a pre-convergence artifact, not a misconfiguration.

**But the per-VLAN port-state table above is confirmed unreliable on this platform**, a separate, genuine
Packet Tracer 9.0.0 limitation. It reports `34 Blocking, 1 Forwarding, 35 STP Active` — yet `show spanning-tree`
(the detailed, per-VLAN command, not the summary) shows every single real interface on every VLAN as `Desg/FWD`,
zero `Blocking` anywhere: VLAN10/20/30/99 each have only `Po1` forwarding, VLAN40 has `Gi1/0/21` + `Po1` both
forwarding. Confirmed by direct cross-check between the two commands, run back to back on the same device -
`show spanning-tree summary`'s Blocking/Listening/Learning/Forwarding/STP-Active columns simply don't reflect
reality here; the root-bridge line above it and the detailed `show spanning-tree` output are both trustworthy.
See [`platform-limitations/`](platform-limitations/) for the confirming screenshots.

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

## WAN Uplinks

`packet-tracer-setup-guide.md` names this as a distinct Phase 1 "should work" checkpoint: each WAN `/30` link
comes up and the directly-connected neighbor's WAN interface is reachable, independent of OSPF entirely (a
directly-connected `/30` ping needs nothing beyond the interface being up with the right IP on both ends - no
routing protocol involved). All three of `MY-KL-HQ-CORE`'s WAN uplinks, tested at once:

<p align="center">
  <img src="./phase-1-basic-connectivity/13-wan-uplinks-ping-my-kl-hq-core.png" alt="MY-KL-HQ-CORE ping to all 3 directly-connected WAN neighbors"><br>
  <sub><code>MY-KL-HQ-CORE# ping 10.10.254.2</code> (SG-EDGE-GW) / <code>ping 10.10.254.6</code> (PH-MNL-ROAS) / <code>ping 10.10.254.10</code> (TH-BKK-ROAS) — all 100% success</sub>
</p>

## Port Security

All three captures below show `Port Status: Secure-down` and `Total MAC Addresses: 0` — these ports were never
actually connected to anything at this point in Phase 1, so this only proves the feature is administratively
configured (enabled, violation mode, max MAC count), not that it actually restricts anything. Real enforcement -
a genuine violation, triggered live - is demonstrated later, in
[`02-security-hardening/threat-simulations/`](../../02-security-hardening/threat-simulations/)'s UDP capture
section (`Gi1/0/3` temporarily set to `maximum 1`, a second MAC address deliberately triggering `violation
restrict`).

<p align="center">
  <img src="./phase-1-basic-connectivity/14-port-security-my-kl-hq-core.png" alt="MY-KL-HQ-CORE port security"><br>
  <sub><code>MY-KL-HQ-CORE# sh port-security int g1/0/11</code></sub>
</p>

<p align="center">
  <img src="./phase-1-basic-connectivity/15-port-security-ph-mnl-acc.png" alt="PH-MNL-ACC port security"><br>
  <sub><code>PH-MNL-ACC# sh port-security int fa0/1</code></sub>
</p>

<p align="center">
  <img src="./phase-1-basic-connectivity/16-port-security-th-bkk-acc.png" alt="TH-BKK-ACC port security"><br>
  <sub><code>TH-BKK-ACC# sh port-security int fa0/1</code></sub>
</p>

**Management SSH** has no Phase 1 evidence in this section by design, not oversight — the only SSH capture in
this project's evidence set is a cross-site session (`TH-BKK-ACC` to `PH-MNL-ACC`), which genuinely requires
cross-site routing that doesn't exist until Phase 2's OSPF is up (see `../topologies/packet-tracer-setup-guide.md`
section 5's "won't work yet" list). It's filed under [Management SSH](#management-ssh) in the Phase 2 section
below, where it actually belongs both technically and chronologically.

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

## Management SSH

An application-layer service, not just ICMP, over that same cross-site reachability — moved here from the Phase 1
section, since it genuinely depends on the OSPF routing established above and couldn't have worked before it
(see `../topologies/packet-tracer-setup-guide.md` section 5's "won't work yet" list, which names exactly this
kind of cross-site LAN access as a Phase 1 limitation).

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/11-ssh-th-bkk-acc-to-ph-mnl-acc.png" alt="SSH TH-BKK-ACC to PH-MNL-ACC"><br>
  <sub><code>TH-BKK-ACC# ssh -l asean.admin 10.10.110.2</code> — cross-site SSH session, TH-BKK-ACC to PH-MNL-ACC, only possible once OSPF routing was up</sub>
</p>

## IPv6 Dual-Stack

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/12-ipv6-int-brief-ph-mnl-roas.png" alt="PH-MNL-ROAS IPv6 interfaces"><br>
  <sub><code>PH-MNL-ROAS# sh ipv6 int brief</code></sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/13-ipv6-int-brief-th-bkk-roas.png" alt="TH-BKK-ROAS IPv6 interfaces"><br>
  <sub><code>TH-BKK-ROAS# sh ipv6 int brief</code></sub>
</p>

`MY-KL-HQ-CORE# sh ipv6 int brief` was captured in two parts below, output paginated past `--More--` at
`Gi1/0/21`. No `Vlan99` entry is expected — VLAN 99 is native-only and was never given its own SVI, consistent
with the HSRP screenshot above (only VLANs 10/20/30/40 have HSRP groups).

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/14-ipv6-int-brief-my-kl-hq-core-part1.png" alt="MY-KL-HQ-CORE IPv6 interfaces, part 1"><br>
  <sub><code>MY-KL-HQ-CORE# sh ipv6 int brief</code> — part 1</sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/15-ipv6-int-brief-my-kl-hq-core-part2.png" alt="MY-KL-HQ-CORE IPv6 interfaces, part 2"><br>
  <sub><code>MY-KL-HQ-CORE# sh ipv6 int brief</code> — part 2</sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/16-ipv6-int-brief-sg-edge-gw.png" alt="SG-EDGE-GW IPv6 interfaces"><br>
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
  <img src="./phase-2-dynamic-routing-ipv6/17-ipv6-route-my-kl-hq-core.png" alt="MY-KL-HQ-CORE IPv6 routing table"><br>
  <sub><code>MY-KL-HQ-CORE# sh ipv6 route</code> — two static routes, one summarized <code>/48</code> per remote site</sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/18-ipv6-route-sg-edge-gw.png" alt="SG-EDGE-GW IPv6 routing table"><br>
  <sub><code>SG-EDGE-GW# sh ipv6 route</code> — single default route back to the hub</sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/19-ipv6-route-ph-mnl-roas.png" alt="PH-MNL-ROAS IPv6 routing table"><br>
  <sub><code>PH-MNL-ROAS# sh ipv6 route</code> — single default route back to the hub</sub>
</p>

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/20-ipv6-route-th-bkk-roas.png" alt="TH-BKK-ROAS IPv6 routing table"><br>
  <sub><code>TH-BKK-ROAS# sh ipv6 route</code> — single default route back to the hub</sub>
</p>

This is the real end-to-end proof: IPv6 dual-stack now means addressing *and* routing, not just addressing.

<p align="center">
  <img src="./phase-2-dynamic-routing-ipv6/21-ping-ipv6-ph-mnl-roas-to-th-bkk-roas.png" alt="Cross-site IPv6 ping, PH-MNL-ROAS to TH-BKK-ROAS"><br>
  <sub><code>PH-MNL-ROAS# ping 2001:DB8:4:10:250:FFF:FEC1:DD01</code> — genuinely cross-site (Manila to Bangkok's MGMT address), 100% success</sub>
</p>

## Confirmed Packet Tracer Limitations

Everything above proves something works. These three prove the opposite — that Packet Tracer 9.0.0's simulated IOS
itself can't do something (or can't report it correctly), regardless of how correct the config is — backing up the
claims already made in the [EtherChannel](#etherchannel), [IPv6 Cross-Site Routing](#ipv6-cross-site-routing), and
[HSRP & Spanning Tree](#hsrp--spanning-tree) sections above with actual screenshots instead of just prose.

**`show lacp` does not exist on this platform.** Alphabetically, a `lacp` keyword would sit between `ipv6` and
`license` in the command tree — it isn't there. Confirmed by paging through the complete `sh ?` output on
`MY-KL-HQ-CORE` rather than assuming from one failed attempt. `show etherchannel summary`/`show etherchannel
<group> detail` are the working alternative used throughout the EtherChannel troubleshooting above.

<p align="center">
  <img src="./platform-limitations/01-show-lacp-not-supported-part1.png" alt="sh ? output, part 1, no lacp keyword"><br>
  <sub><code>MY-KL-HQ-CORE# sh ?</code> — part 1 of 2</sub>
</p>

<p align="center">
  <img src="./platform-limitations/02-show-lacp-not-supported-part2.png" alt="sh ? output, part 2, no lacp keyword"><br>
  <sub><code>MY-KL-HQ-CORE# sh ?</code> — part 2 of 2, list ends with no <code>lacp</code> entry anywhere</sub>
</p>

**`passive-interface` under `ipv6 router ospf` rejects standard `GigabitEthernet1/0/22` syntax**, even though
that exact interface name works everywhere else in this project (`interface GigabitEthernet1/0/22`, `ip ospf
1 area 0`, every other command that takes an interface argument). This is what actually forced the OSPFv3
design to drop `passive-interface` entirely and enable `ipv6 ospf 1 area 0` directly per-interface instead — a
decision explained in the IPv6 Cross-Site Routing section above, now backed by the actual failure it was based on.

<p align="center">
  <img src="./platform-limitations/03-passive-interface-ipv6-ospf-invalid-input.png" alt="passive-interface Invalid input error under ipv6 router ospf"><br>
  <sub><code>MY-KL-HQ-CORE(config-rtr)# no passive-interface g1/0/22</code> — <code>% Invalid input detected at '^' marker</code></sub>
</p>

**`show spanning-tree summary`'s per-VLAN port-state counts don't match reality on this platform.** The summary
table (see [HSRP & Spanning Tree](#hsrp--spanning-tree) above) reports dozens of ports `Blocking` and almost none
`Forwarding`. The detailed `show spanning-tree` output below, captured back to back on the same device, shows the
opposite: every real interface on every VLAN is `Desg/FWD` — zero `Blocking` anywhere. The root-bridge line and
the detailed per-VLAN view are both trustworthy; the summary table's port-state columns are not.

<p align="center">
  <img src="./platform-limitations/04-spanning-tree-detail-vlans-all-forwarding-part1.png" alt="show spanning-tree detail, VLANs 10/20/30, all Desg/FWD"><br>
  <sub><code>MY-KL-HQ-CORE# sh spanning-tree</code> — part 1 of 2, VLAN0010/0020/0030, every interface <code>Desg FWD</code></sub>
</p>

<p align="center">
  <img src="./platform-limitations/05-spanning-tree-detail-vlans-all-forwarding-part2.png" alt="show spanning-tree detail, VLANs 40/99, all Desg/FWD"><br>
  <sub><code>MY-KL-HQ-CORE# sh spanning-tree</code> — part 2 of 2, VLAN0040/0099, every interface <code>Desg FWD</code>, zero <code>Blocking</code> anywhere across all 5 VLANs</sub>
</p>

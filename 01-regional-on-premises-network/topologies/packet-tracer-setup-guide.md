# Building This Topology in Cisco Packet Tracer

Practical build guide for standing up `asean-network-topology.md` in Packet
Tracer, pasting in the configs from `switching/` and `router-configs/`, and
verifying what should (and shouldn't yet) work.

## 1. Device picks

Confirmed models actually used to build and verify this lab (Packet Tracer
9.0.0). The `.cfg` file "Platform:" header comments match these exactly —
an earlier draft of this guide claimed the headers were left "aspirational"
(e.g. Catalyst 9300 as a real-deployment target), but that was reconciled
away: every header now states the real PT model below, confirmed directly
against the live lab rather than assumed.

| Config file                | Role                          | Confirmed PT model         |
|-----------------------------|--------------------------------|------------------------------|
| `MY-KL-HQ-CORE.cfg`    | Layer 3 switch (multilayer)   | Catalyst **3650-24PS**        |
| `MY-KL-HQ-DIST.cfg`    | Layer 2 distribution switch — LACP EtherChannel peer for `MY-KL-HQ-CORE` (added later, see item 5 below) | Catalyst **3650-24PS** |
| `PH-MNL-ACC.cfg`       | Layer 2 access switch         | Catalyst **2960-24TT**        |
| `TH-BKK-ACC.cfg`       | Layer 2 access switch         | Catalyst **2960-24TT**        |
| `SG-EDGE-GW.cfg`      | WAN edge router               | **ISR 4331**                   |
| `PH-MNL-ROAS.cfg`     | Router-on-a-stick              | **ISR 4321**                   |
| `TH-BKK-ROAS.cfg`     | Router-on-a-stick              | **ISR 4321**                   |

Rename each device to its exact hostname (right-click → the device's config
tab, or just let the `hostname` line in the pasted config do it) so the lab
matches the docs.

## 2. Wiring — match the diagram in `asean-network-topology.md`

Build the six original devices and connect them per the ASCII diagram: MY
core switch in the middle, one link each to SG edge router, PH ROAS router,
and TH ROAS router; each ROAS router connects down to its site's access
switch via a **single** trunk link (not EtherChannel — see item 1 below for
why).

A seventh device, `MY-KL-HQ-DIST`, gets added later purely to give
`MY-KL-HQ-CORE`'s `Port-channel1` (configured from the start, but unverified
until a peer existed) something real to bundle with — two links,
`Gi1/0/1`↔`Gi1/0/1` and `Gi1/0/2`↔`Gi1/0/2`, both carrying the same trunk/LACP
config. It isn't part of the routed topology and isn't referenced anywhere
else in the diagram; see item 5 below for a real gotcha hit wiring this up.

Packet Tracer assigns interface names per the exact model you pick, which
will **not** always match the `GigabitEthernet1/0/22` / `GigabitEthernet0/0/1`
style names written into the `.cfg` files (those were written for real
Catalyst 9000 stack-style and ISR4000 numbering). That's expected — when you
paste a config in, **edit the interface names to whatever PT actually shows
you** for each link (check with `show ip interface brief` after wiring), but
keep every IP address, VLAN, and description exactly as written so the
addressing plan stays intact.

## 3. Known Packet Tracer / hardware constraints — read before wiring

1. **No EtherChannel between the ROAS routers and their access switches —
   by design, not a PT limitation.** The ISR4321 (used for `PH-MNL-ROAS.cfg`
   and `TH-BKK-ROAS.cfg`) only has **2 onboard GigabitEthernet ports**
   (Gi0/0/0, Gi0/0/1) — real hardware constraint, not a Packet Tracer quirk.
   A 2-member LACP bundle to the switch would consume both, leaving nothing
   for the WAN link back to MY HQ. So each ROAS router uses a **single**
   trunk (Gi0/0/0, with `.10`/`.20`/`.30`/`.40`/`.99` sub-interfaces) to its
   switch, and Gi0/0/1 for the WAN link — 2 ports total, fits exactly. The
   matching switch side (`PH-MNL-ACC.cfg`/`TH-BKK-ACC.cfg`) uses a single
   trunk port (Gi1/0/23) to match; Gi1/0/24 is left free as a spare. If your
   ISR4321 has NIM expansion slots populated with extra Gigabit modules you
   could go back to a 2-port EtherChannel instead, but the configs as written
   don't require it.
2. **`enable secret 9 $9$REPLACE_WITH_TYPE9_HASH`.** This is a placeholder
   pre-hashed value, not something you can paste as-is on real hardware or in
   PT and get a working password. Replace it with a plaintext secret and let
   the device hash it itself: `enable secret YourPasswordHere`.
3. **`username netadmin privilege 15 secret REPLACE_WITH_ADMIN_PASSWORD`** —
   same deal, swap in a real password before pasting.
4. **`crypto key generate rsa general-keys modulus 2048`** prompts interactively on real
   IOS for confirmation in some cases; in Packet Tracer it should apply
   directly. If SSH still won't come up afterward, double check `ip domain-name`
   is set (it is, in all six configs) since RSA key generation needs it.
5. **LACP EtherChannel can get stuck stand-alone even with correct config on
   both ends — confirmed on `MY-KL-HQ-CORE`↔`MY-KL-HQ-DIST`.** `show
   etherchannel summary` showing `Po1(SD)`/flag `I` (not `P`) on both member
   ports, despite byte-for-byte matching `channel-group 1 mode active` on
   both switches, isn't necessarily a config mistake — it happened here even
   after a plain `shutdown`/`no shutdown` interface bounce. What fixed it:
   fully removing and re-adding channel-group membership on **both**
   switches (`no channel-group 1` / `no channel-protocol lacp`, then
   re-apply `channel-protocol lacp` + `channel-group 1 mode active`), not
   just flapping the link. If you hit this, go straight to the full
   remove-and-re-add.
6. **OSPFv3 (`ipv6 router ospf`) does not form adjacencies on this Packet
   Tracer build — confirmed exhaustively, not assumed.** If you're rebuilding
   Phase 2's IPv6 routing and reach for OSPFv3 to mirror the IPv4 OSPFv2
   design, stop — it was tried first, with config verified correct via
   `show ipv6 protocols`, `show ipv6 ospf interface brief`, a full interface
   bounce, and a full process rebuild on the simplest possible isolated link,
   and it never once formed a neighbor (`Nbrs F/C` stayed `0/0` everywhere).
   OSPFv2 works fine on the same physical links, so this is a genuine
   simulator limitation. Use static IPv6 routes instead — see
   `asean-network-topology.md`'s "Phase 2 — IPv6 routing plan" section for
   the exact routes, and `../evidences/README.md`'s "IPv6 Cross-Site
   Routing" section for the full troubleshooting record.

## 4. Paste order per device

1. Console into the device (click it → CLI tab).
2. Enter global config: `enable` → `configure terminal`.
3. Paste the file's contents **minus the `!`-only comment header block at the
   top** (PT's CLI handles inline comments fine, but paste in smaller chunks
   if you hit the terminal's paste buffer limit — split at each `!` section).
4. `end` then `copy running-config startup-config` to save.

Do this for all six original devices (plus `MY-KL-HQ-DIST` once you get to
it), adjusting interface names per device 2 above as you go.

## 5. What should work right now — and what won't yet

This is Phase 1 output only — no OSPF exists yet, so:

**Should work:**
- All VLANs, trunks, and port security show up correctly (`show vlan brief`,
  `show interfaces trunk`, `show port-security`)
- Rapid PVST+ elects MY-KL-HQ-CORE as root (`show spanning-tree summary`)
- HSRP is active on MY's SVIs (`show standby brief`)
- Each WAN `/30` link comes up and you can `ping` the directly-connected
  neighbor's WAN interface (e.g. from MY, `ping 10.10.254.6` reaches PH's
  router; `ping 10.10.254.2` reaches SG's router)
- SSH works locally at each site once you've swapped in real passwords per
  section 3

**Won't work yet (expected, not a bug):**
- Pinging from a Manila or Bangkok LAN VLAN across to Malaysia HQ, Singapore,
  or each other — MY's core switch has no route back into PH/TH's internal
  VLANs yet, and PH/TH only have a static default route toward MY. This gets
  fixed when OSPF Area 0 goes in during Phase 2.
- Anything involving the SG-to-AWS IPsec tunnel or WLC/wireless — those are
  Phase 4 and later Phase 1 wireless work respectively, not built yet.

Once you've got this much pinging correctly end-to-end (WAN links up, no
cross-site LAN reachability), you're in the right state to start Phase 2.

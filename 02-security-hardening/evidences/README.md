# Phase 3 — Verification Screenshots

Live `show` command output from Packet Tracer, captured as evidence that the security-hardening config in
`../../01-regional-on-premises-network/switching/` and `router-configs/` behaves as documented in
[`../phase3-plan.md`](../phase3-plan.md) — not just written and assumed correct.

- [`layer2-active-defense/`](layer2-active-defense/) — DHCP Snooping, Dynamic ARP Inspection
- [`nat/`](nat/) — static NAT + PAT overload on `SG-EDGE-GW`
- [`access-control-lists/`](access-control-lists/) — `MGMT-SSH-ONLY`, `GUEST-CONTAINMENT`, `WAN-EDGE-INBOUND`

**Known gap found while capturing this evidence:** `access-control-lists/04-access-lists-sg-edge-gw.png` shows
`SG-EDGE-GW`'s live ACL set as only `NAT-INSIDE-HOSTS`, `MGMT-SSH-ONLY`, and `MGMT-SSH-ONLY-V6` —
**`WAN-EDGE-INBOUND` is missing.** That ACL is committed in `SG-EDGE-GW.cfg` (added to close the unfiltered DMZ
exposure — see that file's own comments), but this screenshot proves it was never actually typed into the live
Packet Tracer lab. The `.cfg` file describes the intended, correct config; this folder documents what's actually
running. Needs to be applied live and re-verified.

## Layer 2 Active Defense

**DHCP Snooping** — enabled on VLANs 10/20/30/40 everywhere. Two things worth flagging honestly rather than
glossing over, both only visible on `MY-KL-HQ-CORE`'s output (the access switches use a shorter/different
`show ip dhcp snooping` template on their platform that doesn't include these fields at all, so there's nothing
to cross-check against):
- `DHCP snooping is operational on following VLANs: none` — despite `configured on following VLANs: 10,20,30,40`
  immediately above it. "Configured" and "operational" showing different results on the same device is worth
  investigating rather than assuming it's fine; it might be a genuine gap, or it might be another Packet Tracer
  simulation quirk like the others already confirmed in `../../01-regional-on-premises-network/evidences/platform-limitations/`.
  Not confirmed either way yet.
- The "DHCP snooping trust/rate is configured on the following Interfaces" table has a header row but zero
  interface entries under it — `MY-KL-HQ-CORE` has no explicitly trusted port for snooping. This *might* be
  correct (its DHCP relay happens at Layer 3 via `ip helper-address` on the SVI itself, not through a locally
  snooped Layer 2 uplink the way the access switches' relay path works), but that's a plausible explanation, not
  a verified one - don't take it as confirmed without checking further.

The two access switches are unambiguous, by contrast: each trusts exactly its uplink toward the router that
performs the actual relay, everything else untrusted.

<p align="center">
  <img src="./layer2-active-defense/01-dhcp-snooping-my-kl-hq-core.png" alt="MY-KL-HQ-CORE DHCP snooping"><br>
  <sub><code>MY-KL-HQ-CORE# sh ip dhcp snooping</code> — see the two flagged items above</sub>
</p>

<p align="center">
  <img src="./layer2-active-defense/02-dhcp-snooping-ph-mnl-acc.png" alt="PH-MNL-ACC DHCP snooping"><br>
  <sub><code>PH-MNL-ACC# sh ip dhcp snooping</code> — <code>Gi0/2</code> (uplink to <code>PH-MNL-ROAS</code>) trusted</sub>
</p>

<p align="center">
  <img src="./layer2-active-defense/03-dhcp-snooping-th-bkk-acc.png" alt="TH-BKK-ACC DHCP snooping"><br>
  <sub><code>TH-BKK-ACC# sh ip dhcp snooping</code> — <code>Gi0/2</code> (uplink to <code>TH-BKK-ROAS</code>) trusted</sub>
</p>

**Dynamic ARP Inspection** — same trust pattern as DHCP Snooping (DAI relies on the DHCP Snooping binding table,
so the trust boundaries have to match): every access port untrusted, only the uplink toward the router/core
trusted.

<p align="center">
  <img src="./layer2-active-defense/04-arp-inspection-my-kl-hq-core.png" alt="MY-KL-HQ-CORE ARP inspection"><br>
  <sub><code>MY-KL-HQ-CORE# sh ip arp inspection interfaces</code></sub>
</p>

<p align="center">
  <img src="./layer2-active-defense/05-arp-inspection-ph-mnl-acc.png" alt="PH-MNL-ACC ARP inspection"><br>
  <sub><code>PH-MNL-ACC# sh ip arp inspection interfaces</code> — <code>Gi0/2</code> trusted, matching DHCP Snooping</sub>
</p>

<p align="center">
  <img src="./layer2-active-defense/06-arp-inspection-th-bkk-acc.png" alt="TH-BKK-ACC ARP inspection"><br>
  <sub><code>TH-BKK-ACC# sh ip arp inspection interfaces</code> — <code>Gi0/2</code> trusted, matching DHCP Snooping</sub>
</p>

## NAT

**`SG-EDGE-GW`** — 1 static translation programmed (the DMZ core services host, `10.10.40.10` → `203.0.113.3`),
`GigabitEthernet0/0/1` outside / `GigabitEthernet0/0/0` inside. `Hits: 0` is expected — this topology doesn't
model an end-host actually generating outbound traffic through the PAT overload rule, so the counter has
nothing to increment from yet; this confirms the rule is programmed correctly, not that it's been exercised.

<p align="center">
  <img src="./nat/01-nat-statistics-sg-edge-gw.png" alt="SG-EDGE-GW NAT statistics"><br>
  <sub><code>SG-EDGE-GW# sh ip nat statistics</code></sub>
</p>

## Access Control Lists

**`MY-KL-HQ-CORE`** — all 4 ACLs (`MGMT-SSH-ONLY`, `GUEST-CONTAINMENT`, and their IPv6 `-V6` counterparts) in one
view. No match counts shown yet on `GUEST-CONTAINMENT` — confirms the ACL is correctly programmed, not that
guest-sourced traffic has actually been blocked by it (no PC exists in a `GUEST_WIFI` VLAN in this topology to
generate that traffic).

<p align="center">
  <img src="./access-control-lists/01-access-lists-my-kl-hq-core.png" alt="MY-KL-HQ-CORE access lists"><br>
  <sub><code>MY-KL-HQ-CORE# sh access-lists</code></sub>
</p>

**`PH-MNL-ACC`** and **`TH-BKK-ACC`** — both carry `MGMT-SSH-ONLY` only (no local `GUEST-CONTAINMENT` copy; that
ACL lives on the ROAS routers instead, per `../phase3-plan.md`'s ACL placement design).

<p align="center">
  <img src="./access-control-lists/02-access-lists-ph-mnl-acc.png" alt="PH-MNL-ACC access lists"><br>
  <sub><code>PH-MNL-ACC# show access-lists</code></sub>
</p>

<p align="center">
  <img src="./access-control-lists/03-access-lists-th-bkk-acc.png" alt="TH-BKK-ACC access lists"><br>
  <sub><code>TH-BKK-ACC# sh access-lists</code></sub>
</p>

**`SG-EDGE-GW`** — see the known gap noted at the top of this file. Only `NAT-INSIDE-HOSTS`, `MGMT-SSH-ONLY`, and
`MGMT-SSH-ONLY-V6` are actually present; `WAN-EDGE-INBOUND` still needs to be applied live.

<p align="center">
  <img src="./access-control-lists/04-access-lists-sg-edge-gw.png" alt="SG-EDGE-GW access lists"><br>
  <sub><code>SG-EDGE-GW# sh access-lists</code> — <code>WAN-EDGE-INBOUND</code> missing, see note above</sub>
</p>

# AREHI-SECOPS

**ASEAN Regional E-Commerce Hybrid Infrastructure & Hardened SecOps System**

A production-style hybrid infrastructure project built around a real business scenario: a cross-border K-pop
collectibles e-commerce business headquartered in Malaysia, with regional fulfillment hubs in the Philippines and
Thailand, and a cloud on-ramp through Singapore into AWS. The project is deliberately scoped to cover 100% of the
subtopics across three industry certifications simultaneously, using one coherent network rather than three
disconnected study exercises.

**Architect:** Danial Nur Irfan bin Azeze — Bachelor of Computer Science (Networks & Security), Universiti Teknologi
Malaysia · CompTIA Security+ Certified

## Certifications this project maps to

- Cisco **CCNA 200-301**
- CompTIA **Security+ SY0-701**
- **AWS Certified Solutions Architect – Associate (SAA-C03)**

Every configuration objective across the project is explicitly tagged against these three (and only these three —
no tag is forced where it doesn't genuinely apply). See the full-depth certification guides linked below.

## Project status

| Phase | Scope | Status |
|---|---|---|
| **1 — Regional On-Premises Network** | VLANs, trunking, HSRP, EtherChannel, WAN uplinks, port security, SSH | ✅ Complete, verified against live device output |
| **2 — Dynamic Routing & IPv6** | OSPFv2 Area 0, Router ID/Loopback design, DR/BDR tuning, IPv6 dual-stack | ✅ Complete, verified against live device output |
| **3 — Security Hardening & IP Services** | NTP, SNMP, DHCP Snooping/DAI, DHCP relay, NAT, ACLs, real PKI (OpenSSL CA), TCP/UDP packet capture | ✅ Complete, verified against live device output |
| **4 — AWS Cloud Infrastructure** | Multi-AZ VPC, Site-to-Site IPsec VPN, ALB/ASG, RDS, WAF, Terraform | ✅ Complete, written as deployable-quality Terraform (never applied — see below) |
| **5 — Automation & SecOps** | Netmiko/Python automation, Ansible, centralized SIEM | ✅ Complete, written as real-device-ready code (never executed live — see below) |

All 5 phases are now complete. Phase 4's Terraform is intentionally never run against a real AWS account — there
is no live account behind this project, and every hourly-billed resource in the design (NAT Gateways, RDS Multi-AZ
+ replica, EC2, ALB) would accrue real ongoing cost regardless of traffic. The configuration is written to be
complete and correct; see `03-aws-cloud-infrastructure/phase4-plan.md` for the full reasoning. Phase 5's
Netmiko/Ansible code is similarly never executed live, for a different reason: Packet Tracer 9.0.0 has no real-NIC
bridge to a live SSH target (confirmed directly, not assumed — see `04-automation-and-secops/phase5-plan.md`).

## What makes this different from a typical lab writeup

- **Every device config was verified against live `show run` output, not just written and assumed correct.** The
  process caught real bugs — a missing sub-interface encapsulation that silently broke routing despite the link
  showing "up," repeated VLAN-naming typos, a missing OSPF command — all documented in the certification guides
  rather than quietly fixed and forgotten.
- **Real PKI, not a simulated placeholder.** `02-security-hardening/pki-certificates/` contains an actual OpenSSL-built
  internal CA, a real CSR with proper SAN extensions, and a signed certificate — with a verified chain of trust.
- **Platform limitations are documented, not hidden.** Where Packet Tracer's simulated IOS genuinely can't represent
  something real hardware supports (SNMPv3, certain spanning-tree commands, ISR4321's 2-port hardware constraint),
  that's called out explicitly rather than silently worked around.
- **Three full certification-mapped PDF guides** explain not just *what* was configured but *why*, define every
  networking-specific term used, and include IP/routing reference tables for every addressing-related objective.

## Repository structure

```
01-regional-on-premises-network/
├── switching/            # Access/core switch configs (MY-KL-HQ-CORE, PH-MNL-ACC, TH-BKK-ACC)
├── router-configs/       # WAN/ROAS router configs (SG-EDGE-GW, PH-MNL-ROAS, TH-BKK-ROAS)
├── topologies/           # Topology diagram, IPv4/IPv6 addressing plan, Packet Tracer build guide
├── docs/                 # Phase 1 & 2 full-depth certification PDF guides
└── screenshots.docx      # Verification evidence (show command output, topology view)

02-security-hardening/
├── phase3-plan.md        # Server inventory, ACL policy design, TFTP/PCAP workflow notes
├── pki-certificates/     # Real OpenSSL CA, CSR, signed certificate + explanation
├── docs/                 # Phase 3 full-depth certification PDF guide
├── layer2-defense/       # (DHCP Snooping/DAI — configs live inline in the switching/ files above)
├── firewalls-and-acls/   # (ACL policy — see phase3-plan.md; live configs inline in device files)
└── threat-simulations/   # TCP vs UDP packet capture evidence (Packet Tracer Simulation Mode)

03-aws-cloud-infrastructure/
├── terraform/            # VPC, Security Groups/NACLs, ALB/ASG, RDS, WAF, KMS/S3 logging, Site-to-Site VPN
├── security-groups/       # Security Group / NACL rule matrix reference
├── vpn-gateway/           # IPsec Phase 1/2 parameter reference
├── docs/                  # Phase 4 full-depth certification PDF guide
└── phase4-plan.md         # Addressing plan, resource inventory, scope decision

04-automation-and-secops/
├── python-scripts/        # Netmiko config backup, bulk ACL update, device inventory (this one actually runs)
├── ansible-playbooks/     # Declarative VLAN + ACL deployment (cisco.ios collection)
├── logging-dashboard/     # Wazuh SIEM (Docker Compose) + representative sample logs
├── docs/                  # Phase 5 full-depth certification PDF guide
└── phase5-plan.md         # Scope decision (incl. the Packet Tracer real-NIC bridge finding), resource inventory
```

## Start here

- **Topology & addressing plan:** [`01-regional-on-premises-network/topologies/asean-network-topology.md`](01-regional-on-premises-network/topologies/asean-network-topology.md)
- **Phase 1 guide (on-prem basics):** [`01-regional-on-premises-network/docs/phase1-certification-guide.pdf`](01-regional-on-premises-network/docs/phase1-certification-guide.pdf)
- **Phase 2 guide (OSPF + IPv6):** [`01-regional-on-premises-network/docs/phase2-certification-guide.pdf`](01-regional-on-premises-network/docs/phase2-certification-guide.pdf)
- **Phase 3 guide (security hardening):** [`02-security-hardening/docs/phase3-certification-guide.pdf`](02-security-hardening/docs/phase3-certification-guide.pdf)
- **Phase 4 guide (AWS cloud infrastructure):** [`03-aws-cloud-infrastructure/docs/phase4-certification-guide.pdf`](03-aws-cloud-infrastructure/docs/phase4-certification-guide.pdf)
- **Phase 5 guide (automation & SecOps):** [`04-automation-and-secops/docs/phase5-certification-guide.pdf`](04-automation-and-secops/docs/phase5-certification-guide.pdf)
- **Packet Tracer build guide:** [`01-regional-on-premises-network/topologies/packet-tracer-setup-guide.md`](01-regional-on-premises-network/topologies/packet-tracer-setup-guide.md)

## Lab platform

Built and verified in **Cisco Packet Tracer 9.0.0**, using confirmed device models: Catalyst 3650-24PS (core),
Catalyst 2960-24TT (access), ISR 4331 (WAN edge), ISR 4321 (router-on-a-stick, ×2). PKI work (Phase 3) uses real
OpenSSL on the host machine, not a Packet Tracer simulation.

# Phase 5 — Automation & SecOps Plan

Reference plan for Phase 5 (`04-automation-and-secops/`), same "design first, then build" approach as every
previous phase. Maps to **CCNA 200-301** (Domain 6.0 — Automation and Programmability) and **Security+ SY0-701**
(Domain 4.0 — Security Operations, specifically log aggregation/correlation and SIEM).

## Scope decision — confirmed via direct testing, not assumed

Netmiko and Ansible both require a real, reachable SSH endpoint. Before writing any automation code, this project
checked whether Packet Tracer 9.0.0 can actually expose one: the `PT-Cloud` device (WAN Emulation category) was
placed on the canvas and its Connections tab inspected directly. Its only connection types are **Frame Relay,
DSL, and Cable** — all Packet-Tracer-internal WAN emulation types. There is no option to bridge to a real host
network adapter anywhere in this build, unlike older Packet Tracer versions' Cloud-PT feature. This is a
confirmed platform capability gap, not a misconfiguration — see
`01-regional-on-premises-network` platform-limitations notes for the same treatment given to the SNMPv3 and SVI
ACL findings in earlier phases.

**Consequence:** unlike Phase 4 (where LocalStack provided a genuine, if partial, live-apply target), there is no
equivalent live-execution option available for Phase 5. The Netmiko and Ansible code in this phase is written to
be genuinely correct, idiomatic, real-device-ready automation — but it is **never executed against a live
target**, the same honest treatment given to every other Packet-Tracer-imposed limitation in this project.

**One exception:** `python-scripts/device_inventory.py` needs no live connection at all — it parses this
repository's own `.cfg` reference files directly and emits a structured JSON/YAML inventory. This one genuinely
runs, and its output is committed as proof.

## SIEM data source decision

Same reasoning applies to the logging pipeline: real-time syslog forwarding from Packet Tracer to a local SIEM
would need the same real-NIC bridge that doesn't exist in this build. Wazuh (chosen SIEM — see below) is instead
fed **representative sample logs**, manually drawn from this project's own real `show run` / ACL hit-counter /
SSH-login output collected across Phases 1–3, clearly labeled as samples rather than a live feed.

**Unlike the Netmiko/Ansible pieces, a live Wazuh deployment was actually attempted** on the development machine
(not just planned and skipped) — see `logging-dashboard/README.md`'s "Live Deployment Attempt" section for the
full record. It surfaced and ruled out three separate Docker Desktop/WSL2 environment quirks in turn, none of
which reflect a problem with the Wazuh configuration itself (every cert path/filename was verified directly
against each container's own real config). The live deployment could not be completed on that specific machine;
the configuration is documented as correct-but-unverified-live, the same honest category as the Netmiko/Ansible
code, just arrived at through actually trying rather than ruling it out up front.

## Why Wazuh

Purpose-built open-source SIEM/XDR, chosen over a generic ELK stack specifically because its pre-built security
rule sets, compliance dashboards, and log-correlation model map directly onto Security+ SY0-701 Domain 4.0 content
— the exam objective this phase is heaviest on. Deployed as a single-node Docker Compose stack, consistent with
this project's LocalStack precedent of using a free, local, containerized tool rather than a paid/hosted service.

## Resource inventory (what each file/folder contains)

| Path | Contents |
|---|---|
| `python-scripts/backup_configs.py` | Netmiko script - connects to all 6 devices, pulls `show running-config`, saves timestamped backups. Reference-only, never executed live. |
| `python-scripts/bulk_acl_update.py` | Netmiko script - pushes an ACL update across the 3 routers in one run instead of typing it 3 times by hand. Reference-only. |
| `python-scripts/device_inventory.py` | Parses this repo's own `.cfg` files (no live connection needed) and emits a JSON device inventory. **Actually runs** - output committed as `device_inventory.json`. |
| `python-scripts/devices.py` | Shared device connection-parameter list (hostnames, IPs, device_type) imported by the other scripts. |
| `ansible-playbooks/inventory.ini` | Ansible inventory listing all 6 devices with their real management IPs from the addressing plan. |
| `ansible-playbooks/deploy_vlan_acl.yml` | Playbook using the `cisco.ios` collection to push VLAN + ACL configuration. Reference-only. |
| `ansible-playbooks/ansible.cfg` | Standard Ansible project configuration. |
| `logging-dashboard/docker-compose.yml` | Single-node Wazuh stack (indexer + manager + dashboard). |
| `logging-dashboard/sample-logs/` | Representative sample log files, sourced from this project's own real output. |
| `logging-dashboard/README.md` | Pipeline explanation, ingestion steps, what dashboards/rules to look for. |

## Device inventory used throughout this phase

| Hostname | Real platform (confirmed) | Management IP | Site |
|---|---|---|---|
| `MY-KL-HQ-CORE` | Catalyst 3650-24PS | 10.10.10.2 | Kuala Lumpur |
| `SG-EDGE-GW` | ISR 4331 | 10.255.255.2 (Loopback0) | Singapore |
| `PH-MNL-ROAS` | ISR 4321 | 10.10.110.1 | Manila |
| `PH-MNL-ACC` | Catalyst 2960-24TT | 10.10.110.2 | Manila |
| `TH-BKK-ROAS` | ISR 4321 | 10.10.120.1 | Bangkok |
| `TH-BKK-ACC` | Catalyst 2960-24TT | 10.10.120.2 | Bangkok |

SSH username throughout: `asean.admin` (matches the SSH configuration objective from Phase 1).

## Certification mapping

- **CCNA 200-301 Domain 6.0 (Automation and Programmability):** the entire premise of this phase — Netmiko for
  legacy CLI automation, Ansible for declarative/idempotent configuration management, and the conceptual
  distinction between the two (imperative CLI scripting vs. declarative desired-state) is directly tested.
- **Security+ SY0-701 Domain 4.0 (Security Operations):** the SIEM pipeline — log aggregation, correlation,
  alerting — plus the automation angle itself (Domain 4.0 also covers automation/orchestration for incident
  response and patching at a conceptual level).

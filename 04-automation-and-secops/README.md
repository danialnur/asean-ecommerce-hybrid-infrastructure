# Phase 5 — Automation & SecOps

✅ **Complete** — written as genuinely correct, real-device-ready automation code, with one important honesty
note: Packet Tracer 9.0.0 has no real-NIC bridge (confirmed directly via `PT-Cloud`'s Connections tab — only
Frame Relay/DSL/Cable, no Ethernet/real-adapter option), so the Netmiko and Ansible code here is never executed
against a live device — see `phase5-plan.md` for the full reasoning. `python-scripts/device_inventory.py` needs
no live connection at all (it parses this repo's own `.cfg` files) and genuinely runs — its output is committed
as proof. `ansible-playbooks/deploy_vlan_acl.yml` was installed and syntax-checked for real (Ansible + the
`cisco.ios` collection via WSL Ubuntu, since Ansible's control node doesn't support native Windows) — confirmed
mechanically valid, including the full inventory resolving all 6 devices correctly, even though it was never
applied to a live device. A live Wazuh deployment was also genuinely attempted (not just planned) — see
`logging-dashboard/README.md`'s "Live Deployment Attempt" for the honest record of the 3 Docker Desktop/WSL2
environment quirks that blocked the full stack, and a 4th, unrelated finding: the manager's own default
config ships with no syslog listener at all (only encrypted agent enrollment). Found, fixed, and live-verified
end-to-end with a standalone container test — a real test message was sent and genuinely captured, and the
`allowed-ips` scoping was confirmed to actually reject out-of-scope traffic — independent of whether the full
3-service stack ever comes up on this machine. Full transcript in
`logging-dashboard/evidence-syslog-listener-verified.txt`.

## Scope

- **Netmiko automation** (`python-scripts/`): config backup across all 6 devices, bulk ACL updates across the 3
  devices carrying the GUEST-CONTAINMENT ACL, and a device inventory generator that actually runs
- **Ansible** (`ansible-playbooks/`): declarative VLAN + extended ACL deployment using the `cisco.ios` collection,
  installed and syntax-checked for real via WSL
- **SIEM** (`logging-dashboard/`): single-node Wazuh stack (Docker Compose), fed representative sample logs
  (reconstructed in real Cisco IOS syslog format from this project's own real design) — a live deployment was
  attempted and blocked by environment-specific issues, not a configuration error (see the folder's README)

## Folders

- `python-scripts/` — `backup_configs.py`, `bulk_acl_update.py`, `device_inventory.py` (+ its real output,
  `device_inventory.json`), `devices.py`, `requirements.txt`
- `ansible-playbooks/` — `inventory.ini`, `deploy_vlan_acl.yml`, `ansible.cfg`
- `logging-dashboard/` — `docker-compose.yml`, `sample-logs/`, `README.md`
- `evidences/` — real terminal screenshots proving `device_inventory.py`'s run and Ansible's install/syntax-check/
  inventory-resolution, personally captured rather than only documented (growing — see the folder's own README)
- `phase5-plan.md` — scope decision (including the PT-Cloud bridge finding), resource inventory, cert mapping

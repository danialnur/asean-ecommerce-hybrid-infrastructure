"""
Shared device inventory for the Netmiko scripts in this folder.

REFERENCE ONLY - see ../phase5-plan.md. Packet Tracer 9.0.0 has no real-NIC
bridge (confirmed by inspecting PT-Cloud's Connections tab: only Frame
Relay/DSL/Cable, no Ethernet/real-adapter option), so nothing in this file
has ever been connected to. Management IPs below match the confirmed
addressing plan in
01-regional-on-premises-network/topologies/asean-network-topology.md.
"""

import os

# Never hardcode credentials - read from the environment instead, the same
# principle applied throughout Phase 4 (random_password + Secrets Manager,
# never a plaintext password in a .tf file). A real deployment would use a
# proper secrets store (Ansible Vault, AWS Secrets Manager, etc.) rather
# than even an env var, but this is the minimum viable improvement over
# hardcoding.
SSH_USERNAME = os.environ.get("AREHI_SSH_USER", "asean.admin")
SSH_PASSWORD = os.environ.get("AREHI_SSH_PASSWORD")  # None if unset - scripts must check

DEVICES = [
    {
        "name": "MY-KL-HQ-CORE",
        "host": "10.10.10.2",
        "device_type": "cisco_ios",
        "role": "core-switch",
        "site": "Kuala Lumpur",
    },
    {
        "name": "SG-EDGE-GW",
        "host": "10.255.255.2",  # Loopback0 - no local MGMT VLAN at this site
        "device_type": "cisco_ios",
        "role": "wan-edge-router",
        "site": "Singapore",
    },
    {
        "name": "PH-MNL-ROAS",
        "host": "10.10.110.1",
        "device_type": "cisco_ios",
        "role": "roas-router",
        "site": "Manila",
    },
    {
        "name": "PH-MNL-ACC",
        "host": "10.10.110.2",
        "device_type": "cisco_ios",
        "role": "access-switch",
        "site": "Manila",
    },
    {
        "name": "TH-BKK-ROAS",
        "host": "10.10.120.1",
        "device_type": "cisco_ios",
        "role": "roas-router",
        "site": "Bangkok",
    },
    {
        "name": "TH-BKK-ACC",
        "host": "10.10.120.2",
        "device_type": "cisco_ios",
        "role": "access-switch",
        "site": "Bangkok",
    },
]

# The 3 devices carrying the GUEST-CONTAINMENT extended ACL in Phase 3 -
# used by bulk_acl_update.py. Deliberately excludes SG-EDGE-GW, which only
# has the standard MGMT-SSH-ONLY ACL (no local GUEST_WIFI VLAN to contain
# at that site) - matching the exact objective scope from Phase 3, not
# just "every router."
GUEST_CONTAINMENT_DEVICES = [d for d in DEVICES if d["name"] in ("MY-KL-HQ-CORE", "PH-MNL-ROAS", "TH-BKK-ROAS")]


def connection_params(device: dict) -> dict:
    """Build the dict Netmiko's ConnectHandler expects for one device."""
    if not SSH_PASSWORD:
        raise RuntimeError(
            "AREHI_SSH_PASSWORD is not set. Export it before running any "
            "script in this folder - never hardcode it here."
        )
    return {
        "device_type": device["device_type"],
        "host": device["host"],
        "username": SSH_USERNAME,
        "password": SSH_PASSWORD,
    }

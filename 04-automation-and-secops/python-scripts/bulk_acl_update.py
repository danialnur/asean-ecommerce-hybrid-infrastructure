"""
Bulk ACL update - adds a new deny entry to the GUEST-CONTAINMENT extended
ACL across all 3 devices that carry it, in one run instead of typing the
same change 3 times by hand.

REFERENCE ONLY - never executed against a live device. See
../phase5-plan.md for why. This script is written to be genuinely correct
against real Cisco IOS hardware reachable over SSH.

Scenario demonstrated: a new subnet (10.10.50.0/24, a hypothetical new
DMZ_SERVERS expansion hosted at MY-KL-HQ) needs to be added to
GUEST-CONTAINMENT's deny list at all 3 sites carrying that ACL - matching
the ACL's existing full-mesh pattern, where every site's GUEST_WIFI is
already denied from reaching every site's sensitive subnets, not just its
own local ones (see any device's existing GUEST-CONTAINMENT entries).

Usage (if ever run against a reachable device):
    export AREHI_SSH_PASSWORD="..."
    export AREHI_ENABLE_SECRET="..."
    python bulk_acl_update.py
"""

from netmiko import ConnectHandler
from netmiko.exceptions import NetmikoAuthenticationException, NetmikoTimeoutException

from devices import GUEST_CONTAINMENT_DEVICES, connection_params

NEW_DMZ_EXPANSION_SUBNET = "10.10.50.0 0.0.0.255"


def deny_line_for(device: dict) -> str:
    # The source must be *this device's own* GUEST_WIFI subnet, not a
    # shared constant - each site has a different real subnet (MY-KL:
    # 10.10.30.0/24, PH-MNL: 10.10.112.0/24, TH-BKK: 10.10.122.0/24; see
    # devices.py), so a single hardcoded source would silently push the
    # wrong site's subnet to 2 of the 3 devices.
    return f"deny ip {device['guest_wifi_subnet']} {NEW_DMZ_EXPANSION_SUBNET}"


def commands_for(device: dict) -> list[str]:
    # ACL entries insert by sequence number - inserting before the trailing
    # "permit ip any any" (which Phase 3's design always keeps as the final
    # line) requires knowing that line's sequence number ahead of time. This
    # is why `ip access-list resequence` is run first on every device: it
    # guarantees predictable sequence numbers (10, 20, ...) regardless of
    # how many entries a given device's ACL has accumulated, rather than
    # guessing or parsing `show access-lists` output to find the right
    # number. Every device's real ACL currently has 9 denies + 1 permit
    # (seq 10-90 deny, 100 permit after resequencing), so the new entry
    # goes in at seq 100, pushing the permit-any-any to seq 110.
    return [
        "ip access-list resequence GUEST-CONTAINMENT 10 10",
        "ip access-list extended GUEST-CONTAINMENT",
        f" 100 {deny_line_for(device)}",
    ]


def update_device(device: dict) -> None:
    print(f"[{device['name']}] connecting to {device['host']}...")
    try:
        with ConnectHandler(**connection_params(device)) as conn:
            conn.enable()
            output = conn.send_config_set(commands_for(device))
            conn.save_config()
    except NetmikoAuthenticationException:
        print(f"[{device['name']}] AUTH FAILED - check AREHI_SSH_USER/AREHI_SSH_PASSWORD")
        return
    except NetmikoTimeoutException:
        print(f"[{device['name']}] TIMEOUT - device unreachable at {device['host']}")
        return

    print(f"[{device['name']}] applied:\n{output}\n")


def main() -> None:
    print(f"Pushing new deny entry to {len(GUEST_CONTAINMENT_DEVICES)} devices: "
          f"{[d['name'] for d in GUEST_CONTAINMENT_DEVICES]}")
    print(f"New DMZ expansion subnet: {NEW_DMZ_EXPANSION_SUBNET}\n")

    for device in GUEST_CONTAINMENT_DEVICES:
        update_device(device)

    print(
        "NOTE: MY-KL-HQ-CORE applies GUEST-CONTAINMENT as a Port ACL on "
        "GigabitEthernet1/0/10 (Phase 3 SVI workaround), not on the Vlan30 "
        "SVI - the ACL's own entries are identical either way since the ACL "
        "definition itself is unaffected by *where* it's applied, only "
        "`ip access-group` placement differs. This script only edits the "
        "ACL definition, so it's correct for all 3 devices unchanged."
    )


if __name__ == "__main__":
    main()

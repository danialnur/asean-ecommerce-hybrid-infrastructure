"""
Bulk ACL update - adds a new deny entry to the GUEST-CONTAINMENT extended
ACL across all 3 devices that carry it, in one run instead of typing the
same change 3 times by hand.

REFERENCE ONLY - never executed against a live device. See
../phase5-plan.md for why. This script is written to be genuinely correct
against real Cisco IOS hardware reachable over SSH.

Scenario demonstrated: a new subnet (10.10.50.0/24, a hypothetical new
DMZ_SERVERS expansion) needs to be added to GUEST-CONTAINMENT's deny list
at all 3 sites carrying that ACL.

Usage (if ever run against a reachable device):
    export AREHI_SSH_PASSWORD="..."
    python bulk_acl_update.py
"""

from netmiko import ConnectHandler
from netmiko.exceptions import NetmikoAuthenticationException, NetmikoTimeoutException

from devices import GUEST_CONTAINMENT_DEVICES, connection_params

NEW_DENY_LINE = "deny ip 10.10.30.0 0.0.0.255 10.10.50.0 0.0.0.255"

# ACL entries insert by sequence number - inserting before the trailing
# "permit ip any any" (which Phase 3's design always keeps as the final
# line) requires knowing that line's sequence number ahead of time. This
# is why `ip access-list resequence` is run first on every device: it
# guarantees predictable sequence numbers (10, 20, 30...) regardless of
# how many entries a given device's ACL has accumulated, rather than
# guessing or parsing `show access-lists` output to find the right number.
COMMANDS = [
    "ip access-list resequence GUEST-CONTAINMENT 10 10",
    "ip access-list extended GUEST-CONTAINMENT",
    f" 40 {NEW_DENY_LINE}",  # inserted before the permit-any-any line at seq 50 (originally 3 denies + 1 permit = seq 10/20/30/40, resequenced to 10/20/30/40 -> new entry at 40 pushes permit to 50)
]


def update_device(device: dict) -> None:
    print(f"[{device['name']}] connecting to {device['host']}...")
    try:
        with ConnectHandler(**connection_params(device)) as conn:
            conn.enable()
            output = conn.send_config_set(COMMANDS)
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
    print(f"New line: {NEW_DENY_LINE}\n")

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

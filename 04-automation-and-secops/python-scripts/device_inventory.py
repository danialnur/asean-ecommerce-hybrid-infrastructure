"""
Device inventory summary generator.

Unlike every other script in this folder, this one needs NO live SSH
connection at all - it parses this repository's own `.cfg` reference files
directly and emits a structured JSON inventory. This is the one piece of
Phase 5 automation that genuinely runs; see ../phase5-plan.md for why the
Netmiko/Ansible scripts elsewhere in this folder don't.

Usage:
    python device_inventory.py
Writes device_inventory.json in this same folder.
"""

import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).parents[2]
CFG_DIRS = [
    REPO_ROOT / "01-regional-on-premises-network" / "switching",
    REPO_ROOT / "01-regional-on-premises-network" / "router-configs",
]

HOSTNAME_RE = re.compile(r"^hostname (\S+)", re.MULTILINE)
VLAN_RE = re.compile(r"^vlan (\d+)\n name (\S+)", re.MULTILINE)
INTERFACE_HEADER_RE = re.compile(r"^interface (\S+)")
DESCRIPTION_RE = re.compile(r"^ description (.+)")
IP_ADDRESS_RE = re.compile(r"^ ip address (\S+) (\S+)")


def _interface_blocks(text: str) -> list[list[str]]:
    """Collect each 'interface X' line together with its own indented
    sub-lines only. Triggers directly off 'interface ' headers rather than
    splitting on lone '!' separators - an earlier version of this function
    split on '!' instead, which broke whenever a multi-line '! ----'
    comment banner preceded an interface declaration without a blank '!'
    between them (common in this repo's files): the interface header ended
    up buried mid-block instead of at position 0, and the real ip address
    got silently dropped. Caught by actually running this script against
    the real files and checking the output, not assumed correct on the
    first attempt - SG-EDGE-GW.cfg went from 3 routed interfaces found to
    0 after the first fix attempt, which is what exposed this."""
    blocks: list[list[str]] = []
    for line in text.splitlines():
        if INTERFACE_HEADER_RE.match(line):
            blocks.append([line])
        elif blocks and line.startswith(" "):
            blocks[-1].append(line)
        # any other line (comment, blank, '!', top-level command) ends
        # whatever interface block was open, simply by not being appended
    return blocks


def parse_device(cfg_path: Path) -> dict:
    text = cfg_path.read_text()

    hostname_match = HOSTNAME_RE.search(text)
    hostname = hostname_match.group(1) if hostname_match else cfg_path.stem

    vlans = [
        {"id": int(vlan_id), "name": name}
        for vlan_id, name in VLAN_RE.findall(text)
    ]

    interfaces = []
    for block in _interface_blocks(text):
        name = INTERFACE_HEADER_RE.match(block[0]).group(1)
        description = None
        ip_address = None
        subnet_mask = None
        for line in block[1:]:
            if desc_match := DESCRIPTION_RE.match(line):
                description = desc_match.group(1)
            elif ip_match := IP_ADDRESS_RE.match(line):
                ip_address, subnet_mask = ip_match.groups()
        if ip_address:  # only routed interfaces - matches this script's stated purpose
            interfaces.append(
                {
                    "name": name,
                    "description": description,
                    "ip_address": ip_address,
                    "subnet_mask": subnet_mask,
                }
            )

    return {
        "hostname": hostname,
        "source_file": str(cfg_path.relative_to(REPO_ROOT)),
        "vlans": vlans,
        "routed_interfaces": interfaces,
    }


def main() -> None:
    inventory = []
    for cfg_dir in CFG_DIRS:
        for cfg_path in sorted(cfg_dir.glob("*.cfg")):
            inventory.append(parse_device(cfg_path))

    output_path = Path(__file__).parent / "device_inventory.json"
    output_path.write_text(json.dumps(inventory, indent=2))

    print(f"Parsed {len(inventory)} devices -> {output_path.name}")
    for device in inventory:
        print(
            f"  {device['hostname']}: {len(device['vlans'])} VLANs, "
            f"{len(device['routed_interfaces'])} routed interfaces"
        )


if __name__ == "__main__":
    main()

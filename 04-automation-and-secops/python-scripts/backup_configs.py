"""
Config backup automation - connects to all 6 devices and saves a timestamped
copy of `show running-config` for each, the automated equivalent of the
manual `copy running-config tftp:` objective from Phase 3.

REFERENCE ONLY - never executed against a live device. See
../phase5-plan.md for why (Packet Tracer 9.0.0 has no real-NIC bridge).
This script is written to be genuinely correct against real Cisco IOS
hardware reachable over SSH.

Usage (if ever run against a reachable device):
    export AREHI_SSH_PASSWORD="..."
    export AREHI_ENABLE_SECRET="..."
    python backup_configs.py
"""

import datetime
from pathlib import Path

from netmiko import ConnectHandler
from netmiko.exceptions import NetmikoAuthenticationException, NetmikoTimeoutException

from devices import DEVICES, connection_params

BACKUP_DIR = Path(__file__).parent / "backups"


def backup_device(device: dict) -> None:
    print(f"[{device['name']}] connecting to {device['host']}...")
    try:
        with ConnectHandler(**connection_params(device)) as conn:
            conn.enable()
            running_config = conn.send_command("show running-config")
    except NetmikoAuthenticationException:
        print(f"[{device['name']}] AUTH FAILED - check AREHI_SSH_USER/AREHI_SSH_PASSWORD")
        return
    except NetmikoTimeoutException:
        print(f"[{device['name']}] TIMEOUT - device unreachable at {device['host']}")
        return

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")
    filename = BACKUP_DIR / f"{device['name'].lower()}-{timestamp}.cfg"
    filename.write_text(running_config)
    print(f"[{device['name']}] saved {filename.name} ({len(running_config)} bytes)")


def main() -> None:
    BACKUP_DIR.mkdir(exist_ok=True)
    for device in DEVICES:
        backup_device(device)


if __name__ == "__main__":
    main()

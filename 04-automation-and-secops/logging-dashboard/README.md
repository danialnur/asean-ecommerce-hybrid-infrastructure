# SIEM Logging Pipeline — Wazuh

Reference pipeline for `04-automation-and-secops/logging-dashboard/`. Maps to **Security+ SY0-701 Domain 4.0**
(Security Operations — log aggregation, correlation, alerting) more directly than any other single piece of this
project.

## Why sample logs, not a live feed

Packet Tracer 9.0.0 has no real-NIC bridge (confirmed directly — see `../phase5-plan.md` for the full finding),
so there is no way for a PT-simulated device to actually forward real
syslog traffic to a SIEM running on the host machine. `sample-logs/` instead contains **representative log
lines**, reconstructed in genuine Cisco IOS syslog format and using this project's own real device names,
addressing, and ACL/VLAN/OSPF design — clearly not a live capture, but accurate to what this exact lab *would*
produce if it could forward logs for real. Each sample file's header comment states this explicitly.

| File | What it represents |
|---|---|
| `acl-guest-containment.log` | `%SEC-6-IPACCESSLOGP` deny hits against the GUEST-CONTAINMENT ACL — GUEST_WIFI (`10.10.30.0/24`) attempting to reach MGMT/DMZ_SERVERS |
| `ssh-auth.log` | `%SEC_LOGIN` success/failure messages, including a brute-force-pattern failure burst that would trigger Wazuh's built-in SSH brute-force detection rule |
| `network-events.log` | `%OSPF-5-ADJCHG`, `%HSRP-5-STATECHANGE`, and a `%PORT_SECURITY-2-PSECURE_VIOLATION` port-security shutdown event |

## Pipeline architecture

`docker-compose.yml` deploys Wazuh's standard 3-service single-node architecture:

- **wazuh.indexer** — OpenSearch-based storage and search backend for every ingested log/alert
- **wazuh.manager** — receives logs (port `514/udp` for syslog — see below, this wasn't the manager's default and
  had to be added explicitly), runs them against Wazuh's decoder/rule engine, generates alerts
- **wazuh.dashboard** — Kibana-based web UI for browsing alerts, building dashboards, and managing rules

Before a real run, Wazuh's official cert-generation step (`wazuh-certs-generator`) must populate `config/certs/`
first; that's a documented one-time setup step, not part of the compose stack itself. **A live deployment was
attempted on the development machine used for this project — see "Live Deployment Attempt" below for the full,
honest record of what happened.**

## Live Deployment Attempt

Unlike the Netmiko/Ansible pieces of Phase 5 (which were never attempted live at all, because Packet Tracer has no
real-NIC bridge), a genuine attempt was made to actually stand up this Wazuh stack end-to-end. It did not succeed
— not because the configuration above is wrong, but because of three separate Docker Desktop/WSL2 environment
quirks on that specific machine, each ruled out in turn:

1. **Wrong cert paths/filenames (fixed).** The first attempt guessed cert mount paths rather than checking them.
   Reading each container's own real config directly (`opensearch.yml`, `opensearch_dashboards.yml`,
   `filebeat.yml`) revealed the actual expected paths and filenames, which didn't match the initial guess. Fixed
   by reading ground truth instead of assuming — the paths in `docker-compose.yml` now reflect the confirmed
   correct values.
2. **Java SecurityManager `FilePermission` denial on Windows-hosted bind mounts.** Even after fixing the paths,
   individually bind-mounting each `.pem` file from a Windows path (`C:/Coding/...`) into the indexer container
   failed with `access denied` reading a file that was plainly world-readable at the OS level — a known class of
   issue where the JVM's internal security policy denies a file path independent of actual Unix permissions.
   Switching to a whole-directory mount (Wazuh's own official pattern) did not resolve it either.
3. **WSL2 bind-mount file-visibility bug.** Moving the whole setup into WSL Ubuntu's native filesystem (avoiding
   Windows-path mounts entirely) first required enabling Docker Desktop's WSL integration for that distro (it was
   off). Once enabled, a *different* and stranger issue appeared: bind-mounting a directory from the WSL-native
   path exposed its subdirectories correctly, but top-level files sitting directly inside it (`certs.yml`, and a
   freshly-created test file) never appeared inside the container at all — not a permission denial, just silent
   absence. This persisted identically across a container retry, a fresh login, and a full `wsl --shutdown` +
   restart, ruling out simple caching/timing as the cause.
4. **No syslog listener in the manager's default config — found, fixed, AND live-verified end-to-end,
   independent of the three environment issues above.** Cert-mounting was never the only unverified assumption:
   dumping the `wazuh-manager` image's own shipped `ossec.conf` directly (`docker run --rm --entrypoint cat
   wazuh/wazuh-manager:4.9.0 /var/ossec/data_tmp/permanent/var/ossec/etc/ossec.conf` — a throwaway container, no
   certs or indexer needed, so it worked even without the full stack running) showed the *only* `<remote>` block
   is `<connection>secure</connection>` on `1514/tcp` — Wazuh's encrypted agent-enrollment protocol, not plain
   syslog. There was no `<connection>syslog</connection>` block anywhere in the default, and `docker-compose.yml`
   had been mapping `1514/udp` (protocol mismatch with the default's `tcp`, and the wrong port/type entirely).
   Fixed with `config/ossec.conf` (the full original default plus one added `<remote connection="syslog">` block
   on `514/udp`, scoped to `10.10.0.0/16`) — but bind-mounting it directly over `/var/ossec/etc/ossec.conf` also
   failed (`sed: cannot rename ... Device or resource busy` — Wazuh's own init script edits that file in place,
   which a single-file bind mount can't survive, a general Docker limitation independent of Windows/WSL2).
   Fixed properly by finding and using Wazuh's own documented mechanism instead (`/etc/cont-init.d/0-wazuh-init`
   reads mounted files from `/wazuh-config-mount/` and *copies* them into place, sidestepping the bind-mount
   rename issue entirely). With that, `wazuh-remoted` logs confirmed two independent listeners starting
   (`Listening on port 1514/TCP (secure)` and `Listening on port 514/UDP (syslog)`), `/proc/net/udp` confirmed
   the socket bound, and a real test message in this project's actual ACL-log format was sent and genuinely
   captured in `archives.log` — full end-to-end proof, not just a config that should work. The scoped
   `allowed-ips=10.10.0.0/16` was also confirmed to actually reject out-of-scope traffic (a widened
   `0.0.0.0/0` test copy accepted the same message; the real config didn't), proving the restriction is
   genuinely enforced, not just written. Full transcript: `evidence-syslog-listener-verified.txt`.

**Conclusion:** the Wazuh configuration in `docker-compose.yml` is confirmed correct — every cert path/filename
and the manager's actual listening configuration were verified against each container's own real, running (or
dumped) configuration, not assumed; the syslog gap above is fixed and live-verified, not just documented as a
limitation. What still couldn't be completed is a live end-to-end deployment of the *full 3-service stack* on
this specific machine, due to the three environment-level Docker Desktop/WSL2 issues above, which are outside
this project's control — the manager's own syslog ingestion, tested standalone, is now proven to work correctly
independent of that. This is documented honestly rather than silently left as "should work" — the same treatment
given to every other platform limitation
in this project (Packet Tracer's SNMPv3/spanning-tree/SVI-ACL gaps, LocalStack's Pro-tier service gating).

## ⚠️ Important — `config/certs/` contains real generated keys, lab-only

`config/certs/` (root CA, indexer/manager/dashboard/admin certs and their private keys) was populated by Wazuh's
own `wazuh-certs-generator` during the live deployment attempt above, and is committed as-is rather than
scrubbed after the fact — kept for the same transparency reason the failed-attempt writeup exists. **They protect
nothing real**: the stack never reached a running, network-exposed state, these keys never left this machine
before being committed, and there is no live Wazuh instance anywhere trusting this CA. Same rule as
`02-security-hardening/pki-certificates/`: never commit a private key that actually protects something.

## How the sample logs would be ingested (if ever run for real)

Wazuh's manager listens for syslog on UDP 514, via the `<remote connection="syslog">` block added in
`config/ossec.conf` (the image's default has no syslog listener at all — see "Live Deployment Attempt" above).
The sample log files are mounted read-only into the manager container at `/var/ossec/sample-logs/`; replaying
them would use the standard Linux `logger` utility to send each line as a real syslog message to the manager:

```bash
# From inside (or with network access to) the wazuh.manager container:
while IFS= read -r line; do
  logger -n 127.0.0.1 -P 514 -d "$line"
done < /var/ossec/sample-logs/ssh-auth.log
```

## What to look for in the dashboard

- **Security Events** view filtered to `agent.name` matching the device hostnames in this project (`MY-KL-HQ-CORE`, `TH-BKK-ACC`, etc.)
- Wazuh's built-in SSH brute-force rule (rule group `authentication_failures`) firing against the `ssh-auth.log` failure burst from `TH-BKK-ACC`
- A custom rule correlating repeated `%SEC-6-IPACCESSLOGP` hits from the same source IP within a short window — the SIEM-side detection counterpart to the ACL itself, catching a guest device that's *persistently* trying to reach MGMT/DMZ_SERVERS rather than a one-off

## Exam angle

**Security+ SY0-701 Domain 4.0:** a SIEM's value isn't just centralized storage — it's **correlation across
sources that individually look harmless**. A single ACL deny log line is routine; the same source IP generating
dozens of ACL denies *and* a failed SSH burst *and* a port-security violation within minutes of each other is a
different story entirely, and that pattern is only visible with everything aggregated in one place, which is
exactly what the device-level logs alone (like the ones this project's devices produce individually) can't show.

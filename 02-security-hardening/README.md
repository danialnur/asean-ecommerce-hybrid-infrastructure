# Phase 3 — Security Hardening & IP Services

Security+ SY0-701 and CCNA 200-301-mapped hardening pass on top of the Phase 1/2 network: NTP, DHCP Snooping/DAI,
DHCP relay, standard and extended ACLs, and a real internal PKI. Built and verified in Cisco Packet Tracer 9.0.0,
on the same 7-device topology from `../01-regional-on-premises-network/` (`MY-KL-HQ-DIST` excluded — it's an
EtherChannel-only device with no SSH/ACL/port-security surface, see that folder's topology doc).

Full design rationale, the placeholder services-server addressing, and the ACL policy tables:
[`phase3-plan.md`](phase3-plan.md).

## In this folder

- [`evidences/`](evidences/) — live verification screenshots (DHCP Snooping, DAI, NAT, ACLs, NTP/SNMP, TFTP
  backup) — includes a gap that was found and fixed live along the way, see that folder's `README.md`
- [`pki-certificates/`](pki-certificates/) — real OpenSSL-built internal CA, CSR, and signed TLS certificate,
  not a simulated placeholder
- [`threat-simulations/`](threat-simulations/) — TCP vs UDP packet capture evidence — TCP handshake done, UDP
  still outstanding (see that folder's `README.md`)

DHCP Snooping/DAI, port security, and ACL config itself lives in `../01-regional-on-premises-network/switching/`
and `router-configs/` — those `.cfg` files carry every Phase 1-3 objective together, not split by phase.

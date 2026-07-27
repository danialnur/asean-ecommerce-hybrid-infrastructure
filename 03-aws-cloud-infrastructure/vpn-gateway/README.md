# Site-to-Site IPsec VPN — On-Prem ↔ AWS

Reference doc for `03-aws-cloud-infrastructure/terraform/vpn-gateway.tf`. This connects the AWS VPC back to the ASEAN on-prem network (`SG-EDGE-GW`, built in Phase 1/2) over an encrypted tunnel across the public internet, rather than a private leased line — the standard hybrid-cloud pattern tested under AWS SAA-C03's "hybrid architecture" objectives and Security+ SY0-701 Domain 3.0 (secure network architecture).

## Honesty note — what is and isn't real here

`SG-EDGE-GW`'s "public" IP (`var.on_prem_customer_gateway_ip` = `203.0.113.2`) is an RFC 5737 documentation/example address assigned inside the Packet Tracer lab. It is not routable on the real internet, and this VPN can never actually establish a live tunnel in this project. The Terraform in `vpn-gateway.tf` is written to be 100% correct and would form a genuine working tunnel against a real on-prem endpoint with a real public IP — the gap here is the lab environment, not the configuration.

## Components (mapped to `vpn-gateway.tf`)

| Terraform resource | AWS concept | Role |
|---|---|---|
| `aws_customer_gateway.sg_edge_gw` | Customer Gateway (CGW) | Represents the on-prem VPN endpoint (`SG-EDGE-GW`) from AWS's point of view — its public IP and BGP ASN |
| `aws_vpn_gateway.main` | Virtual Private Gateway (VGW) | The AWS-side VPN concentrator, attached directly to the VPC |
| `aws_vpn_connection.main` | Site-to-Site VPN Connection | The actual IPsec tunnel pairing between the CGW and VGW |
| `aws_vpn_connection_route.on_prem` | Static route | Tells AWS to route `var.on_prem_cidr` (10.10.0.0/16 — all 4 on-prem sites) down the tunnel |
| `aws_vpn_gateway_route_propagation.*` | Route propagation | Automatically injects VPN-learned routes into the app/db route tables |

## Why static routing, not BGP

`aws_vpn_connection.main` sets `static_routes_only = true`. AWS VPN connections support either static routes or dynamic BGP routing, but `SG-EDGE-GW`'s Phase 1/2 configuration uses static `ip route` statements on its WAN-facing side rather than a routing protocol — so the AWS side is configured to match, rather than introducing BGP only on one end. (A real production deployment reaching multiple, changing on-prem prefixes would typically prefer BGP for its ability to withdraw/advertise routes dynamically — noted here as the tradeoff, not applied.)

## High availability: two tunnels per connection

AWS provisions **two tunnels** per VPN connection by default (`tunnel1_address` / `tunnel2_address` in `outputs.tf`), each terminating at a different AWS public IP in different underlying infrastructure. `SG-EDGE-GW` would ordinarily be configured with two IPsec peer statements — one per tunnel — so that a failure or maintenance event on one AWS endpoint doesn't take down on-prem connectivity entirely. This mirrors the same "no single point of failure" principle already applied to the per-AZ NAT Gateways in `vpc.tf`.

## IPsec parameters (what a real `SG-EDGE-GW` config would need to match)

AWS's default Site-to-Site VPN uses the following IKE/IPsec parameters. A real on-prem router's `crypto isakmp policy` / `crypto ipsec transform-set` would need to match these on both tunnels for negotiation to succeed:

| Parameter | Phase 1 (IKE) | Phase 2 (IPsec) |
|---|---|---|
| Encryption | AES-256 | AES-256 |
| Hashing | SHA-2 (256) | SHA-2 (256) |
| Diffie-Hellman Group | Group 14 | Group 14 |
| Authentication | Pre-shared key (`tunnel1_preshared_key` / `tunnel2_preshared_key`, marked `sensitive` in `outputs.tf`) | — |
| SA Lifetime | 28,800 seconds | 3,600 seconds |
| Mode | Main mode | Tunnel mode |

**Exam note (Security+ SY0-701 Domain 3.0):** IKE Phase 1 establishes a secure, authenticated channel between the two peers themselves (the "control plane" of the tunnel); Phase 2 then negotiates the actual per-flow Security Associations used to encrypt the data traffic. A tunnel that's "up" at Phase 1 but failing at Phase 2 is a classic real-world troubleshooting scenario — matching transform sets/proposals on both ends is what Phase 2 negotiation depends on.

## Route propagation vs. static routes

`vpc.tf`'s `aws_route_table.app` and `aws_route_table.db` already hardcode a static route to `var.on_prem_cidr` via `aws_vpn_gateway.main.id`. `aws_vpn_gateway_route_propagation` in `vpn-gateway.tf` additionally enables automatic route propagation from the VGW into those same route tables. In a real deployment where the on-prem side used BGP, propagation would be the only way routes appear at all (no static entry would exist); here, with static routing on both ends, both mechanisms coexist — the explicit static route in `vpc.tf` guarantees reachability even if propagation were ever disabled, while propagation is left enabled to demonstrate the mechanism AWS SAA-C03 tests separately from static routes.

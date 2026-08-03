# Phase 4 — AWS Cloud Infrastructure Plan

Reference plan for Phase 4 (`03-aws-cloud-infrastructure/`), same "design first, then build" approach as every
previous phase. Maps to **AWS SAA-C03** (Domains 1.0–4.0) and **Security+ SY0-701** (Domain 3.0).

## Scope decision

This Terraform is written as complete, correct, deployable-quality reference code — but **it is never actually
applied**. No `terraform apply` is run against a real AWS account as part of this project; there's no live AWS
account behind this work, and deploying it for real would incur ongoing hourly costs (NAT Gateway, RDS, EC2, ALB
all bill by the hour regardless of traffic). This mirrors how the on-premises phases treated the AWS-facing
placeholder interface (`203.0.113.0/24`, RFC 5737) — represented accurately, never assumed to be live.

**A consequence of this:** the Phase 1 "Site-to-Site VPN" objective was always going to be config-only for the
same reason — `SG-EDGE-GW` is a Packet Tracer device with a placeholder public IP that has no real internet
reachability, so a live IPsec tunnel to a real AWS Virtual Private Gateway was never going to actually establish
regardless of how this phase is built. Confirmed directly, not just assumed: `SG-EDGE-GW`'s `Gi0/0/1` (the
interface carrying `203.0.113.2`) shows `down/down` in `show ip interface brief` — no physical link exists,
discovered while root-causing why the on-prem static NAT rule's `Hits` counter stayed at 0 (see
`../02-security-hardening/evidences/README.md`'s "NAT" section). The Terraform below configures the **AWS side**
of that tunnel correctly (Customer Gateway pointed at the placeholder IP, VPN Gateway, VPN Connection) as
genuine, correct infrastructure code — it just can't be paired with a live negotiation partner in this lab.

## VPC addressing plan

Parent CIDR: `10.200.0.0/16` (per the original blueprint), region `ap-southeast-1` (Singapore — geographically
consistent with `SG-EDGE-GW` being the on-prem side of the hybrid connection), spanning **2 Availability Zones**
for the multi-AZ resilience AWS SAA-C03 specifically tests.

| Tier | AZ `ap-southeast-1a` | AZ `ap-southeast-1b` | Purpose |
|---|---|---|---|
| Public | `10.200.0.0/24` | `10.200.1.0/24` | ALB, NAT Gateways — internet-facing |
| Private App | `10.200.10.0/24` | `10.200.11.0/24` | EC2 web/app tier (Auto Scaling Group) |
| Private DB | `10.200.20.0/24` | `10.200.21.0/24` | RDS Multi-AZ primary + read replica |

Same VLSM logic as the on-prem network: each tier gets a `/24` (256 addresses, generous for what each tier
actually needs), and the second digit of the third octet doubles as a tier identifier (`0`/`1` = public, `10`/`11`
= app, `20`/`21` = DB) — consistent with how the on-prem plan used the third octet to encode VLAN purpose.

## Resource inventory (what each `.tf` file will contain)

| File | Contents |
|---|---|
| `vpc.tf` | VPC, 6 subnets (3 tiers × 2 AZs), Internet Gateway, 2 NAT Gateways (one per AZ, for true multi-AZ resilience — a single NAT Gateway would be a single point of failure), route tables |
| `security-groups.tf` | Security Groups (stateful, instance-level) for ALB/app/DB tiers, plus Network ACLs (stateless, subnet-level) as a second defense layer |
| `alb.tf` | Application Load Balancer, target group, HTTPS + HTTP-redirect listeners, launch template, Auto Scaling Group |
| `rds.tf` | Multi-AZ RDS instance (PostgreSQL), read replica; credentials via `manage_master_user_password = true` (RDS generates and owns its own Secrets Manager secret — Terraform never sees the plaintext password) |
| `waf.tf` | AWS WAF Web ACL attached to the ALB, with managed rule groups for SQLi and XSS plus a per-IP rate-limit rule |
| `logging.tf` | KMS key + encrypted S3 bucket for audit logging |
| `vpn-gateway.tf` | Customer Gateway (pointed at `SG-EDGE-GW`'s placeholder IP), Virtual Private Gateway, Site-to-Site VPN Connection |
| `variables.tf` / `outputs.tf` | Shared input variables and output values referenced across the other files |

## Security posture mapped to Security+ SY0-701 Domain 3.0

- **Security Groups** (stateful — return traffic automatically allowed) vs. **NACLs** (stateless — must explicitly
  permit both directions) are deliberately both used, not just one, specifically to demonstrate understanding of
  the distinction the exam tests directly.
- **Defense in depth, tier by tier:** the ALB's Security Group only accepts 443 from the internet; the app tier's
  Security Group only accepts traffic from the ALB's Security Group (not from the internet directly, not even from
  the whole VPC CIDR); the DB tier's Security Group only accepts traffic from the app tier's Security Group on the
  database port. No tier trusts anything wider than the one tier immediately in front of it.
- **WAF** sits in front of the ALB specifically to catch SQLi/XSS at the HTTP layer, before it ever reaches the
  application — a different layer of defense than the network-level Security Groups/NACLs below it.

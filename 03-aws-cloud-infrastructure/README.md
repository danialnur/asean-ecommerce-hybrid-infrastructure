# Phase 4 — AWS Cloud Infrastructure

✅ **Complete** — written as full, deployable-quality Terraform reference code, deliberately never applied against a
real AWS account (no live account, and every hourly-billed resource here would incur real ongoing cost — see
`phase4-plan.md` for the full reasoning). That's not the whole story, though: a genuine `terraform plan` → `apply`
→ verify → `destroy` cycle was run against LocalStack (a local AWS API emulator) for the free-tier-available
subset — VPC, subnets, security groups, routing, KMS/S3 logging, IAM, and the VPN connection itself were actually
created and destroyed, not just planned. ALB, RDS, and WAF are LocalStack Pro-gated services, so those pieces were
only ever validated with `terraform plan`, never applied even to LocalStack — see `docs/screenshots.md` for the
full disclosure of exactly what was and wasn't applied.

## Scope

- Multi-AZ VPC (`10.200.0.0/16`, `ap-southeast-1`) with public/private-app/private-DB subnet tiers across 2 AZs
- Internet Gateway + one NAT Gateway per AZ (no single point of failure), per-AZ route tables
- Security Groups (stateful) + Network ACLs (stateless) — strict tier-to-tier trust model
- Application Load Balancer + Auto Scaling Group (target-tracking scaling on CPU) for the K-pop e-commerce web app
- Multi-AZ Amazon RDS (PostgreSQL) with a read replica, credentials in AWS Secrets Manager (never plaintext)
- AWS WAF on the ALB — managed rule groups for SQLi/XSS, plus a custom rate-based rule
- KMS-encrypted, versioned S3 bucket for ALB access logs / audit trail
- Site-to-Site IPsec VPN (Customer Gateway, Virtual Private Gateway, VPN Connection) back to `SG-EDGE-GW`

## Folders

- `terraform/` — `main.tf`, `variables.tf`, `vpc.tf`, `security-groups.tf`, `alb.tf`, `rds.tf`, `waf.tf`,
  `logging.tf`, `vpn-gateway.tf`, `outputs.tf`
- `security-groups/README.md` — full Security Group / NACL rule matrix with reasoning
- `vpn-gateway/README.md` — IPsec Phase 1/2 parameter reference
- `docs/screenshots.md` + `docs/screenshots/` — LocalStack `plan`/`apply`/`destroy` evidence
- `phase4-plan.md` — addressing plan, resource inventory, and the honesty note on why this is never deployed

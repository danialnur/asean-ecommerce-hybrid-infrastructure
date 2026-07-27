# Phase 4 — AWS Cloud Infrastructure

✅ **Complete** — written as full, deployable-quality Terraform reference code, deliberately never applied against a
real AWS account (no live account, and every hourly-billed resource here would incur real ongoing cost — see
`phase4-plan.md` and the certification guide for the full reasoning).

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
- `docs/phase4-certification-guide.pdf` — full-depth, AWS SAA-C03-centered certification study guide
- `phase4-plan.md` — addressing plan, resource inventory, and the honesty note on why this is never deployed

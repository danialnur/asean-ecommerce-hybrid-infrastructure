# Phase 4 — AWS Cloud Infrastructure

🚧 **Not started yet.**

Planned scope (per the project blueprint):
- Multi-AZ VPC (`10.200.0.0/16`, `ap-southeast-1`) with public/private/database subnet tiers
- Site-to-Site IPsec VPN (IKEv2, AES-256) from `SG-EDGE-GW` to an AWS Virtual Private Gateway/Transit Gateway
- Application Load Balancer + Auto Scaling Group for the K-pop e-commerce web app
- Multi-AZ Amazon RDS (MySQL/PostgreSQL) with a read replica, credentials in AWS Secrets Manager
- AWS WAF on the ALB, Security Groups + NACLs, KMS-encrypted S3 audit logging
- Terraform (`main.tf`, `vpc.tf`, `alb.tf`, `rds.tf`) for all of the above

Planned folders: `terraform/`, `security-groups/`, `vpn-gateway/`.

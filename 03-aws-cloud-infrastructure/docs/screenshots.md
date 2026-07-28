# Phase 4 — LocalStack Validation Screenshots

Evidence of a full `terraform plan` → `apply` → verify → `destroy` cycle run against **LocalStack** (a local AWS
API emulator), not a real AWS account — see `../phase4-plan.md` for why this project never applies the Terraform
in `../terraform/` against real AWS. LocalStack still exercises the actual Terraform code and the AWS provider's
API calls, so this confirms the configuration is mechanically correct, not just written and assumed correct.
(Converted from the original `screenshots.docx` so it renders directly on GitHub instead of requiring a download.)

## Plan & Apply

**`terraform plan`** — 68 resources to add, full output plan (VPC, subnets, ALB, RDS, WAF, KMS, VPN, Secrets Manager)
![terraform plan summary](screenshots/01-terraform-plan-summary.png)

**`awslocal secretsmanager delete-secret`** — clearing a previous run's RDS master-credentials secret before re-applying
![awslocal delete-secret](screenshots/02-awslocal-delete-secret.png)

**`terraform apply` complete** — 5 added, 0 changed, 1 destroyed; outputs include subnet IDs, audit log bucket, KMS key ARN, VPN tunnel addresses
![terraform apply complete](screenshots/03-terraform-apply-complete.png)

## Verifying Applied Resources

**`awslocal ec2 describe-subnets`** — all 6 subnets (public/app/db × 2 AZs) with correct AZ and CIDR
![awslocal describe-subnets](screenshots/04-awslocal-describe-subnets.png)

**`awslocal ec2 describe-security-groups`** — `arehi-secops-alb-sg`: HTTPS from internet in, app tier only out
![Security group: ALB](screenshots/05-awslocal-describe-security-groups-alb.png)

**`arehi-secops-app-sg`** — app traffic from ALB only in, NAT-routed internet + Postgres to DB tier out
![Security group: app tier](screenshots/06-awslocal-describe-security-groups-app.png)

**`arehi-secops-db-sg`** — Postgres from app tier only in, no egress
![Security group: DB tier](screenshots/07-awslocal-describe-security-groups-db.png)

**`awslocal ec2 describe-vpn-connections`** — full Site-to-Site IPsec config, both tunnels, IKE/IPsec parameters
![awslocal describe-vpn-connections](screenshots/08-awslocal-describe-vpn-connections.png)

## LocalStack Dashboard

**Docker Desktop** — `localstack-main` container running
![Docker Desktop container](screenshots/09-docker-desktop-localstack-container.png)

**Resource Browser — VPCs** — `arehi-secops` VPC (`10.200.0.0/16`) alongside the account default
![LocalStack VPCs](screenshots/10-localstack-resource-browser-vpcs.png)

**Resource Browser — Security Groups** — all 3 tier security groups present with correct descriptions
![LocalStack security groups](screenshots/11-localstack-resource-browser-security-groups.png)

**Status — Services** — EC2, IAM, KMS, S3, Secrets Manager, STS all running
![LocalStack service status](screenshots/12-localstack-status-services-running.png)

**Resource Browser — Subnets** — all 9 subnets across both AZs
![LocalStack subnets](screenshots/13-localstack-resource-browser-subnets.png)

## Teardown

**`terraform destroy` complete** — 53 resources destroyed, clean teardown
![terraform destroy complete](screenshots/14-terraform-destroy-complete.png)

# Security Groups & NACLs — Rule Matrix

Reference doc for `03-aws-cloud-infrastructure/terraform/security-groups.tf`. Two independent layers are used deliberately — Security Groups (stateful, instance-level) and Network ACLs (stateless, subnet-level) — so the design demonstrates the distinction both AWS SAA-C03 and Security+ SY0-701 test directly, rather than relying on just one.

## Trust model

Each tier trusts only the ONE tier immediately in front of it — never "the VPC," never a raw CIDR unless there's no alternative (NACLs, which can't reference security groups, are the one exception). Nothing trusts the raw internet except the ALB's port 443 listener.

```
Internet → [ALB SG: 443] → [App SG: 8443] → [DB SG: 5432]
```

## Security Groups (stateful)

Stateful means: a rule need only be written in ONE direction. If inbound traffic is allowed in, the response traffic is automatically allowed back out, regardless of the egress rules. This is the #1 SG-vs-NACL exam distinction.

Every rule below is a separate `aws_security_group_rule` resource — none of the three `aws_security_group` resources declare any inline `ingress`/`egress` blocks at all. This isn't just a style choice: mixing inline rule blocks with separate `aws_security_group_rule` resources targeting the *same* security group is a confirmed Terraform/AWS-provider anti-pattern. The `aws_security_group` resource treats its own inline blocks as the complete, authoritative rule set, so on every apply it silently deletes any rule that was added out-of-band by a separate rule resource — while that separate resource's own state still believes the rule exists. Caught live via a real `terraform plan` against a LocalStack test run: `aws_security_group.app`'s plan showed it about to delete the 5432-to-`db-sg` egress rule, which would have silently broken database connectivity had it actually been applied. The fix was to move every rule, not just the two that strictly needed it to avoid a circular reference, into its own resource.

| Security Group | Direction | Port | Source/Destination | Reasoning |
|---|---|---|---|---|
| `alb-sg` | Ingress | 443/tcp | `0.0.0.0/0` | Only entry point from the public internet for real traffic. |
| `alb-sg` | Ingress | 80/tcp | `0.0.0.0/0` | Needed so `alb.tf`'s `http_redirect` listener (port 80 → 301 to HTTPS) is actually reachable — nothing is ever served over plaintext, the ALB immediately redirects it. |
| `alb-sg` | Egress | 8443/tcp | `app-sg` | ALB forwards decrypted-and-reencrypted traffic only to the app tier's SG, never to a raw CIDR. |
| `app-sg` | Ingress | 8443/tcp | `alb-sg` | App tier only accepts traffic that has already passed through the ALB — direct internet or intra-VPC access is not possible even if someone had the private IP. |
| `app-sg` | Egress | 443/tcp | `0.0.0.0/0` | Outbound HTTPS for OS patching / package installs, routed via the NAT Gateway (app subnets have no public IP of their own). |
| `app-sg` | Egress | 5432/tcp | `db-sg` | Lets the app tier reach the database — the rule that exposed the mixed-pattern bug described above. |
| `db-sg` | Ingress | 5432/tcp | `app-sg` | Only the app tier may ever open a connection to Postgres — not the ALB, not the bastion, not "the VPC." |
| `db-sg` | Egress | *(none)* | — | No egress rule at all. A database has no legitimate business reason to initiate outbound connections; the SG's implicit "deny all" is intentionally left in place rather than adding a permissive rule "just in case." |

**Exam note (SY0-701 Domain 3.0 / SAA-C03):** referencing a security group ID as a rule's source/destination (rather than a CIDR block) is what lets the rule stay correct even as Auto Scaling adds/removes instances with different private IPs — the group membership is what's evaluated, not a fixed address range.

## Network ACLs (stateless)

Stateless means: return traffic is NOT automatically permitted. Every NACL below has an explicit ephemeral-port ingress/egress rule (1024–65535) specifically so response traffic from an already-permitted connection isn't silently dropped. Rules are evaluated in `rule_no` order, lowest first, first match wins.

| NACL | Direction | Rule # | Port | CIDR | Purpose |
|---|---|---|---|---|---|
| `public-nacl` | Ingress | 100 | 443 | `0.0.0.0/0` | HTTPS from the internet |
| `public-nacl` | Ingress | 105 | 80 | `0.0.0.0/0` | Matches `alb-sg`'s port-80 rule above — same `http_redirect` listener, both layers have to allow it |
| `public-nacl` | Ingress | 110 | 1024–65535 | `0.0.0.0/0` | Ephemeral return traffic for any connection initiated by clients on the internet |
| `public-nacl` | Egress | 100 | all | `0.0.0.0/0` | Public subnet is genuinely public — ALB responses and NAT Gateway traffic both need broad egress |
| `app-nacl` | Ingress | 100 | 8443 | VPC CIDR | App traffic, scoped to the VPC rather than the internet (NACLs can't reference the ALB's SG directly) |
| `app-nacl` | Ingress | 110 | 1024–65535 | `0.0.0.0/0` | Ephemeral return traffic for outbound NAT Gateway connections (patching, etc.) |
| `app-nacl` | Egress | 100 | all | `0.0.0.0/0` | Covers both DB-tier requests and NAT Gateway-bound internet traffic |
| `db-nacl` | Ingress | 100 | 5432 | VPC CIDR | Postgres traffic from within the VPC only |
| `db-nacl` | Ingress | 110 | 1024–65535 | VPC CIDR | Ephemeral return traffic — scoped to the VPC, not the internet, since the DB tier never talks to the internet |
| `db-nacl` | Egress | 100 | 5432 | VPC CIDR | Multi-AZ primary → standby/replica replication traffic — NACLs are stateless, so this needs its own explicit egress rule even though ingress rule 100 already allows 5432 inbound |
| `db-nacl` | Egress | 110 | 1024–65535 | VPC CIDR | DB tier only ever answers back within the VPC — no `0.0.0.0/0` egress rule exists anywhere in this NACL |

**Why NACLs can't fully replace Security Groups here:** a NACL's `cidr_block` can't reference another AWS resource the way a Security Group's `source_security_group_id` can. That's the core exam-testable reason both layers are used together — NACLs give a coarse, stateless, subnet-wide backstop; Security Groups give the precise, stateful, per-tier trust boundary.

## Defense-in-depth summary

If a Security Group were ever misconfigured too permissively (e.g. an engineer accidentally added `0.0.0.0/0` to `db-sg`), the DB subnet's NACL — which only permits VPC-CIDR traffic on 5432 — would still block any connection attempt originating from outside the VPC. Neither layer alone is the whole control; the pairing is the control.

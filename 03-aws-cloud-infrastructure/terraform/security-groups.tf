# =============================================================
# Security Groups (stateful, instance-level) + Network ACLs
# (stateless, subnet-level) - deliberately both, not just one, to
# demonstrate the distinction AWS SAA-C03 and Security+ both test.
# See 03-aws-cloud-infrastructure/security-groups/README.md for the
# full rule matrix in table form.
#
# Trust model: each tier only trusts the ONE tier immediately in
# front of it. The DB tier does not trust "the VPC" - it trusts
# only the app tier's Security Group specifically. Nothing trusts
# the internet except the ALB's HTTPS listener.
# =============================================================

# -------------------------------------------------------------
# ALB tier - only public-facing Security Group in the whole design
# -------------------------------------------------------------
# All rules for every tier below are declared as separate
# aws_security_group_rule resources, deliberately with NO inline
# ingress/egress blocks on the aws_security_group resources
# themselves. Mixing the two styles for the same security group is a
# known Terraform/AWS-provider anti-pattern: the aws_security_group
# resource treats its own inline blocks as the *complete, authoritative*
# rule set and will silently delete any rule added out-of-band by a
# separate aws_security_group_rule on every apply, even though that
# separate resource's own state still believes the rule exists - a
# real, confirmed-live bug (caught via a genuine `terraform plan`
# against LocalStack, not a hypothetical), not just a style preference.
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Internet-facing ALB - HTTPS, plus HTTP for the redirect-to-HTTPS listener"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the internet"
}

# Without this, aws_lb_listener.http_redirect in alb.tf (port 80,
# redirects to 443) is unreachable - the security group would drop
# the traffic before it ever reached the ALB, making that listener
# dead code. Caught by checking the LocalStack SG evidence screenshot
# against alb.tf's listeners rather than assuming the two matched.
resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet - redirected to HTTPS by the ALB listener, never served"
}

resource "aws_security_group_rule" "alb_egress_to_app" {
  type                     = "egress"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.app.id
  description              = "Forward to the app tier only"
}

# -------------------------------------------------------------
# App tier - only accepts traffic FROM the ALB's security group,
# never directly from the internet or even the raw VPC CIDR
# -------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "EC2 web/app tier - only reachable from the ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

resource "aws_security_group_rule" "alb_to_app_ingress" {
  type                     = "ingress"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
  description              = "App traffic from the ALB only"
}

resource "aws_security_group_rule" "app_egress_internet" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "Outbound internet (patching, package installs) via NAT Gateway"
}

resource "aws_security_group_rule" "app_to_db_egress" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.db.id
  description              = "Postgres to the DB tier only"
}

# -------------------------------------------------------------
# DB tier - only accepts traffic FROM the app tier's security
# group, on the database port only. No egress rule at all -
# a database has no legitimate reason to initiate outbound
# connections, so the default "deny all egress" is left in place.
# -------------------------------------------------------------
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "RDS Multi-AZ - only reachable from the app tier, on 5432"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

resource "aws_security_group_rule" "db_ingress_from_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.app.id
  description              = "Postgres from the app tier only"
}

# =============================================================
# Network ACLs - stateless second layer. Unlike Security Groups,
# return traffic must be explicitly permitted in both directions.
# Applied per subnet tier rather than per-instance.
# =============================================================

resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  ingress {
    rule_no    = 105
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80 # matches alb_ingress_http in the SG above - same http_redirect listener
  }
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535 # ephemeral return traffic
  }
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.project_name}-public-nacl"
  }
}

resource "aws_network_acl" "app" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.app[*].id

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 8443
    to_port    = 8443
  }
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.project_name}-app-nacl"
  }
}

resource "aws_network_acl" "db" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.db[*].id

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 5432
    to_port    = 5432
  }
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 5432
    to_port    = 5432 # Multi-AZ primary -> standby/replica replication traffic - NACLs are stateless,
    # so this needs its own explicit egress rule even though ingress rule 100 already allows 5432 inbound.
  }
  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 1024
    to_port    = 65535 # DB tier only ever talks back within the VPC, never to 0.0.0.0/0
  }

  tags = {
    Name = "${var.project_name}-db-nacl"
  }
}

# =============================================================
# VPC, subnets (3 tiers x 2 AZs), Internet Gateway, per-AZ NAT
# Gateways, and route tables. See phase4-plan.md for the addressing
# plan and the reasoning behind per-AZ NAT Gateways.
# =============================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# -------------------------------------------------------------
# PUBLIC SUBNETS - ALB + NAT Gateways live here, one per AZ
# -------------------------------------------------------------
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -------------------------------------------------------------
# NAT GATEWAYS - one per AZ, not one shared NAT Gateway. A single
# shared NAT Gateway would make every private app subnet's internet
# egress depend on one AZ - a real single point of failure that
# would undermine the whole point of a Multi-AZ design.
# -------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${var.availability_zones[count.index]}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-${var.availability_zones[count.index]}"
  }

  depends_on = [aws_internet_gateway.main]
}

# -------------------------------------------------------------
# PRIVATE APP SUBNETS - EC2 web/app tier (Auto Scaling Group).
# Each AZ's app subnet routes outbound through *that AZ's own*
# NAT Gateway, keeping the two AZs independently resilient.
# -------------------------------------------------------------
resource "aws_subnet" "app" {
  count             = length(var.app_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-app-${var.availability_zones[count.index]}"
    Tier = "app"
  }
}

resource "aws_route_table" "app" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  # Route back to the on-prem network via the VPN Gateway - lets the
  # app tier reach the ASEAN on-prem sites over the Site-to-Site VPN.
  # The VGW resource itself lives in vpn-gateway.tf.
  route {
    cidr_block = var.on_prem_cidr
    gateway_id = aws_vpn_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-app-rt-${var.availability_zones[count.index]}"
  }
}

resource "aws_route_table_association" "app" {
  count          = length(aws_subnet.app)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

# -------------------------------------------------------------
# PRIVATE DB SUBNETS - RDS Multi-AZ. Deliberately no route to the
# internet at all (no NAT, no IGW) - a database has no legitimate
# reason to initiate outbound internet traffic, and this removes
# an entire class of exfiltration risk by simply not providing a path.
# -------------------------------------------------------------
resource "aws_subnet" "db" {
  count             = length(var.db_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-db-${var.availability_zones[count.index]}"
    Tier = "db"
  }
}

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  # Still reachable from on-prem over the VPN (e.g. for DB admin
  # tooling), but no default route to the internet at all.
  route {
    cidr_block = var.on_prem_cidr
    gateway_id = aws_vpn_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-db-rt"
  }
}

resource "aws_route_table_association" "db" {
  count          = length(aws_subnet.db)
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

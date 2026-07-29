# =============================================================
# Site-to-Site IPsec VPN - connects this VPC back to the ASEAN
# on-prem network (SG-EDGE-GW, Phase 1/2) over the public internet
# using an encrypted tunnel, rather than a private leased line.
#
# HONESTY NOTE: SG-EDGE-GW's public IP (var.on_prem_customer_gateway_ip,
# 203.0.113.2) is an RFC 5737 documentation address from the Packet
# Tracer lab - it is not routable on the real internet. This
# resource set is written to be 100% correct Terraform and would
# form a real, working tunnel against a real on-prem endpoint, but
# it can never actually establish against this lab. See
# phase4-plan.md for the full reasoning.
# =============================================================

# The on-prem side of the tunnel - SG-EDGE-GW's public-facing
# interface, as far as AWS is concerned
resource "aws_customer_gateway" "sg_edge_gw" {
  bgp_asn    = var.on_prem_bgp_asn
  ip_address = var.on_prem_customer_gateway_ip
  type       = "ipsec.1"

  tags = {
    Name = "${var.project_name}-sg-edge-gw-cgw"
  }
}

# The AWS side of the tunnel - attaches directly to the VPC
resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-vgw"
  }
}

# The actual IPsec VPN connection - AWS provisions 2 tunnels
# (redundant endpoints) per connection by default, each terminating
# at a different AWS public IP for HA on the AWS side
resource "aws_vpn_connection" "main" {
  customer_gateway_id = aws_customer_gateway.sg_edge_gw.id
  vpn_gateway_id      = aws_vpn_gateway.main.id
  type                = "ipsec.1"

  # Static routing rather than BGP dynamic routing - matches
  # SG-EDGE-GW's Phase 1/2 config, which uses static routes rather
  # than a routing protocol on its WAN-facing side
  static_routes_only = true

  tags = {
    Name = "${var.project_name}-vpn-to-sg-edge-gw"
  }
}

# PLATFORM LIMITATION: aws_vpn_connection_route and both
# aws_vpn_gateway_route_propagation resources below are simply "not
# implemented" in LocalStack - confirmed via a real `terraform apply`
# attempt ("The create_vpn_connection_route action has not been
# implemented" / "The enable_vgw_route_propagation action has not been
# implemented"), independent of license tier (unlike the elbv2/rds/wafv2
# gaps elsewhere in this project, which are paid-tier gated, not
# unimplemented). These 3 resources are correct, deployable AWS
# Terraform - verified only via `terraform plan`, not `apply`, in this
# project's local testing. aws_customer_gateway/aws_vpn_gateway/
# aws_vpn_connection above ARE supported and were verified with a real
# `apply` against LocalStack.

# The static route AWS advertises down the tunnel toward the
# on-prem CIDR - the counterpart to the ip route statements already
# configured on SG-EDGE-GW pointing back at this VPC
resource "aws_vpn_connection_route" "on_prem" {
  vpn_connection_id      = aws_vpn_connection.main.id
  destination_cidr_block = var.on_prem_cidr
}

# Propagate the VPN's routes into the app/db route tables automatically
# rather than only relying on the static routes already hardcoded in
# vpc.tf - this lets any future on-prem subnet get reachable without
# editing every route table by hand
resource "aws_vpn_gateway_route_propagation" "app" {
  count          = length(aws_route_table.app)
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = aws_route_table.app[count.index].id
}

resource "aws_vpn_gateway_route_propagation" "db" {
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = aws_route_table.db.id
}

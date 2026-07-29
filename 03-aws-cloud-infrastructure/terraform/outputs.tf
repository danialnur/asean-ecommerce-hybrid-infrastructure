# =============================================================
# Outputs - the values an operator (or a CI/CD pipeline, or the
# on-prem network team configuring SG-EDGE-GW's side of the tunnel)
# would need after a real `terraform apply`.
# =============================================================

output "vpc_id" {
  description = "ID of the main VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB, NAT Gateways)"
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "Private app-tier subnet IDs (Auto Scaling Group)"
  value       = aws_subnet.app[*].id
}

output "db_subnet_ids" {
  description = "Private DB-tier subnet IDs (RDS Multi-AZ)"
  value       = aws_subnet.db[*].id
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "rds_primary_endpoint" {
  description = "Connection endpoint for the RDS primary instance"
  value       = aws_db_instance.primary.endpoint
}

output "rds_read_replica_endpoint" {
  description = "Connection endpoint for the RDS read replica"
  value       = aws_db_instance.read_replica.endpoint
}

output "db_credentials_secret_arn" {
  description = "Secrets Manager ARN holding the RDS master credentials (RDS-managed, via manage_master_user_password)"
  value       = aws_db_instance.primary.master_user_secret[0].secret_arn
}

output "audit_logs_bucket" {
  description = "S3 bucket receiving ALB access logs and audit trail data"
  value       = aws_s3_bucket.audit_logs.id
}

output "kms_key_arn" {
  description = "KMS key ARN used for S3 and RDS encryption at rest"
  value       = aws_kms_key.main.arn
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN protecting the ALB"
  value       = aws_wafv2_web_acl.main.arn
}

output "vpn_connection_id" {
  description = "VPN connection ID - required on the SG-EDGE-GW side to match tunnel configuration"
  value       = aws_vpn_connection.main.id
}

output "vpn_tunnel1_address" {
  description = "AWS-side public IP for VPN tunnel 1 - the peer address SG-EDGE-GW's crypto map would point to"
  value       = aws_vpn_connection.main.tunnel1_address
}

output "vpn_tunnel2_address" {
  description = "AWS-side public IP for VPN tunnel 2 (redundant path)"
  value       = aws_vpn_connection.main.tunnel2_address
}

output "vpn_tunnel1_preshared_key" {
  description = "Pre-shared key for tunnel 1 - would be configured as the ISAKMP key on SG-EDGE-GW"
  value       = aws_vpn_connection.main.tunnel1_preshared_key
  sensitive   = true
}

output "vpn_tunnel2_preshared_key" {
  description = "Pre-shared key for tunnel 2"
  value       = aws_vpn_connection.main.tunnel2_preshared_key
  sensitive   = true
}

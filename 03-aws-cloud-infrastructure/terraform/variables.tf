variable "aws_region" {
  description = "AWS region - Singapore, geographically consistent with SG-EDGE-GW being the on-prem hybrid endpoint"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix applied to every resource name/tag for this project"
  type        = string
  default     = "arehi-secops"
}

variable "vpc_cidr" {
  description = "Parent VPC CIDR block - see phase4-plan.md for the full subnet breakdown"
  type        = string
  default     = "10.200.0.0/16"
}

variable "availability_zones" {
  description = "The 2 AZs this Multi-AZ design spans"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public tier (ALB, NAT Gateways) - one per AZ"
  type        = list(string)
  default     = ["10.200.0.0/24", "10.200.1.0/24"]
}

variable "app_subnet_cidrs" {
  description = "Private app tier (EC2 web/ASG) - one per AZ"
  type        = list(string)
  default     = ["10.200.10.0/24", "10.200.11.0/24"]
}

variable "db_subnet_cidrs" {
  description = "Private DB tier (RDS Multi-AZ) - one per AZ"
  type        = list(string)
  default     = ["10.200.20.0/24", "10.200.21.0/24"]
}

variable "on_prem_cidr" {
  description = "The entire on-premises address space (all 4 sites) reachable via the Site-to-Site VPN"
  type        = string
  default     = "10.10.0.0/16"
}

variable "on_prem_customer_gateway_ip" {
  description = "SG-EDGE-GW's public-facing IP - a Packet Tracer placeholder (RFC 5737), not a real routable address. See phase4-plan.md for why this can never be a live tunnel in this lab."
  type        = string
  default     = "203.0.113.2"
}

variable "on_prem_bgp_asn" {
  description = "BGP ASN for the on-prem side of the VPN connection (private-use ASN range, RFC 6996)"
  type        = number
  default     = 65000
}

variable "db_engine" {
  description = "RDS engine - PostgreSQL, per the blueprint's MySQL/PostgreSQL option"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  type    = string
  default = "16.4"
}

variable "db_instance_class" {
  description = "Free-tier-eligible instance class - this project is never actually deployed, but sizing is chosen realistically anyway"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "arehi_ecommerce"
}

variable "db_master_username" {
  type    = string
  default = "arehi_admin"
}

variable "asg_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 4
}

variable "asg_desired_capacity" {
  type    = number
  default = 2
}

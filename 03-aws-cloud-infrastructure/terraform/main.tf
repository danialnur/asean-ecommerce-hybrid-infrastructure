# =============================================================
# AREHI-SECOPS — Phase 4: AWS Cloud Infrastructure
# Provider/backend configuration only. Resources live in the other
# .tf files in this directory - Terraform merges every .tf file in
# one directory into a single configuration automatically, so this
# split (vpc.tf, alb.tf, rds.tf, etc.) is purely for readability,
# not separate root modules.
#
# NOTE: this configuration is written to be genuinely correct and
# deployable, but is intentionally never applied against a real AWS
# account as part of this project - see phase4-plan.md.
# =============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # A real deployment would configure a remote backend (S3 + DynamoDB
  # lock table) here instead of local state - omitted since this is
  # never actually applied and there is no S3 bucket/table to point to.
  # backend "s3" {
  #   bucket         = "arehi-secops-terraform-state"
  #   key            = "phase4/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   dynamodb_table = "arehi-secops-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project = var.project_name
      Phase   = "phase4-aws-cloud-infrastructure"
      Managed = "terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

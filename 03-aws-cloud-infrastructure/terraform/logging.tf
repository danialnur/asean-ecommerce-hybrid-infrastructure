# =============================================================
# KMS-encrypted S3 bucket for audit logging - ALB access logs land
# here (see alb.tf), implementing an immutable, encrypted
# transaction/audit-log trail for the e-commerce platform.
# =============================================================

resource "aws_kms_key" "main" {
  description             = "${var.project_name} audit log encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-audit-kms-key"
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-audit-logs"
  target_key_id = aws_kms_key.main.key_id
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "audit_logs" {
  bucket = "${var.project_name}-audit-logs-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-audit-logs"
  }
}

# Block every form of public access - defense against the single
# most common real-world S3 misconfiguration (accidentally public
# buckets)
resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
    bucket_key_enabled = true
  }
}

# Versioning - so an accidental delete/overwrite of an audit log
# never actually loses the original record
resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "archive-old-logs"
    status = "Enabled"

    filter {} # empty filter = applies to every object in the bucket

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555 # ~7 years - typical financial-record retention period
    }
  }
}

# ALB access logging requires the regional ELB log-delivery service
# to be explicitly granted PutObject on this bucket
data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowALBLogDelivery"
        Effect    = "Allow"
        Principal = { AWS = data.aws_elb_service_account.main.arn }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.audit_logs.arn}/alb/*"
      },
      {
        Sid       = "DenyUnencryptedTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.audit_logs.arn, "${aws_s3_bucket.audit_logs.arn}/*"]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

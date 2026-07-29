# =============================================================
# RDS Multi-AZ (PostgreSQL) + Read Replica.
# Credentials never appear in plaintext anywhere in this
# configuration, including Terraform state: manage_master_user_password
# (below, on aws_db_instance.primary) has RDS itself generate the master
# password and hold it in a Secrets Manager secret it manages, so
# Terraform never sees or stores the plaintext value at all - a step up
# from the more common random_password + manually-populated secret
# pattern, which puts the password in state regardless of Secrets
# Manager also holding a copy.
#
# PLATFORM LIMITATION: rds is gated behind LocalStack's paid tier -
# confirmed via a real `terraform apply` attempt against a free
# LocalStack license ("the rds service is not included within your
# LocalStack license"). aws_db_subnet_group and both aws_db_instance
# resources below are correct, deployable AWS Terraform - verified only
# via `terraform plan`, not `apply`, in this project's local testing.
# =============================================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# -------------------------------------------------------------
# Primary - Multi-AZ (synchronous standby in the second AZ,
# automatic failover if the primary AZ has a problem)
# -------------------------------------------------------------
resource "aws_db_instance" "primary" {
  identifier     = "${var.project_name}-db-primary"
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_encrypted = true
  kms_key_id        = aws_kms_key.main.arn

  db_name                     = var.db_name
  username                    = var.db_master_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]

  multi_az            = true
  publicly_accessible = false

  backup_retention_period = 7
  backup_window           = "16:00-17:00" # UTC - off-peak for ASEAN business hours
  maintenance_window      = "sun:17:00-sun:18:00"

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-db-primary-final"
  deletion_protection       = true

  tags = {
    Name = "${var.project_name}-db-primary"
  }
}

# -------------------------------------------------------------
# Read replica - offloads reporting/analytics queries (e.g. sales
# and audit-trail dashboards) from the primary, in the
# second AZ for its own independent availability
# -------------------------------------------------------------
resource "aws_db_instance" "read_replica" {
  identifier          = "${var.project_name}-db-read-replica"
  replicate_source_db = aws_db_instance.primary.identifier
  instance_class      = var.db_instance_class

  availability_zone   = var.availability_zones[1]
  publicly_accessible = false

  storage_encrypted = true
  kms_key_id        = aws_kms_key.main.arn

  vpc_security_group_ids = [aws_security_group.db.id]

  skip_final_snapshot = true

  tags = {
    Name = "${var.project_name}-db-read-replica"
  }
}

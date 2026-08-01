# =============================================================
# Application Load Balancer + Auto Scaling Group for the K-pop
# e-commerce web/app tier.
#
# PLATFORM LIMITATION: elbv2 (and therefore aws_lb, aws_lb_target_group,
# both listeners below, plus the ASG/scaling policy further down which
# depend on the target group's ARN) is gated behind LocalStack's paid
# tier - confirmed via a real `terraform apply` attempt against a free
# LocalStack license ("the elbv2 service is not included within your
# LocalStack license"). This resource set is correct, deployable AWS
# Terraform - verified only via `terraform plan`, not `apply`, in this
# project's local testing. The IAM role/instance profile and launch
# template further down are free-tier resources in their own right,
# but they reference aws_db_instance.primary.master_user_secret[0]
# (below and in launch_template's user_data) - an attribute RDS only
# populates on a successful apply, and rds.tf documents that
# aws_db_instance is itself paid-tier-gated on LocalStack. So these
# two resources were never actually apply-tested end-to-end either;
# see 03-aws-cloud-infrastructure/docs/screenshots.md for exactly
# which resources the LocalStack run did apply.
# =============================================================

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  # Access logs land in the same KMS-encrypted bucket used for
  # everything else in Phase 4 - see logging.tf
  access_logs {
    bucket  = aws_s3_bucket.audit_logs.id
    prefix  = "alb"
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-app-tg"
  port     = 8443
  protocol = "HTTPS"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    protocol            = "HTTPS"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = {
    Name = "${var.project_name}-app-tg"
  }
}

# HTTPS listener - the certificate ARN would reference an ACM-issued
# cert in a real deployment. Referencing it as a variable (declared in
# variables.tf, same as every other input) rather than hardcoding, since
# no real ACM certificate exists for this project.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Redirect any stray HTTP traffic straight to HTTPS rather than
# serving anything over plaintext
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# -------------------------------------------------------------
# IAM role for the EC2 instances - specifically scoped to only
# what the app tier needs (read the DB secret), not broad access
# -------------------------------------------------------------
resource "aws_iam_role" "app_instance" {
  name = "${var.project_name}-app-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "app_read_db_secret" {
  name = "${var.project_name}-read-db-secret"
  role = aws_iam_role.app_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_db_instance.primary.master_user_secret[0].secret_arn]
    }]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-app-instance-profile"
  role = aws_iam_role.app_instance.name
}

# -------------------------------------------------------------
# Launch template + Auto Scaling Group
# (the ASG/scaling policy below share the elbv2 PLATFORM LIMITATION
# noted at the top of this file - target_group_arns depends on the
# target group, which LocalStack's free tier can't create)
# -------------------------------------------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.asg_instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  # In a real deployment this would pull the K-pop e-commerce app
  # container/artifact and read DB credentials from Secrets Manager
  # (whose ARN is passed in below) rather than embedding secrets
  # directly in user data.
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "DB_SECRET_ARN=${aws_db_instance.primary.master_user_secret[0].secret_arn}" >> /etc/environment
    # Real deployment: pull and start the application container here
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-app-instance"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = aws_subnet.app[*].id
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_out_on_cpu" {
  name                   = "${var.project_name}-scale-out-cpu"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}

# =============================================================
# AWS WAF - attached directly to the ALB, inspecting HTTP requests
# before they ever reach the application. A different layer of
# defense than the Security Groups/NACLs in security-groups.tf,
# which only look at Layer 3/4 (IP/port) - WAF inspects Layer 7
# request content itself (headers, body, query strings).
#
# PLATFORM LIMITATION: wafv2 is gated behind LocalStack's paid tier -
# confirmed via a real `terraform apply` attempt against a free
# LocalStack license ("the wafv2 service is not included within your
# LocalStack license"). This resource set is correct, deployable AWS
# Terraform - verified only via `terraform plan`, not `apply`, in this
# project's local testing. See 03-aws-cloud-infrastructure/docs/ for
# the full LocalStack validation write-up.
# =============================================================

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-web-acl"
  description = "Blocks SQL injection and XSS against the K-pop e-commerce app, per Security+ SY0-701 Domain 4.5"
  scope       = "REGIONAL" # REGIONAL for ALB; CLOUDFRONT scope would be used for a CDN distribution instead

  default_action {
    allow {}
  }

  # --- SQL Injection protection ---
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 1

    override_action {
      none {} # "none" = respect the managed rule group's own block/count actions
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-sqli-rule-set"
      sampled_requests_enabled   = true
    }
  }

  # --- Cross-Site Scripting (XSS) + general common-attack protection ---
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet" # includes CrossSiteScripting_BODY/QUERYARGUMENTS/COOKIE rules
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  # --- Rate limiting - a basic Layer 7 DoS/brute-force mitigation,
  # separate from the two managed rule groups above ---
  rule {
    name     = "rate-limit-per-ip"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000 # requests per 5-minute window per source IP
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.project_name}-web-acl"
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

resource "aws_wafv2_web_acl" "web" {
  name        = "${var.project_name}-web-acl"
  description = "Web ACL for AWS Multi-AZ Portfolio"

  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # カスタム検証ルール
  rule {
    name     = "block-test-header"
    priority = 0

    action {
      block {}
    }

    statement {
      byte_match_statement {
        search_string         = "block-me"
        positional_constraint = "EXACTLY"

        field_to_match {
          single_header {
            name = "x-portfolio-test"
          }
        }

        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-block-test"
      sampled_requests_enabled   = true
    }
  }

  # AWS管理ルール
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = {
    Name      = "${var.project_name}-web-acl"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# WAFログ保存用CloudWatch Logs
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.project_name}"
  retention_in_days = 14

  tags = {
    Name      = "aws-waf-logs-${var.project_name}"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# WAFログの送信設定
resource "aws_wafv2_web_acl_logging_configuration" "web" {
  resource_arn = aws_wafv2_web_acl.web.arn

  log_destination_configs = [
    aws_cloudwatch_log_group.waf.arn
  ]

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }
    }
  }
}

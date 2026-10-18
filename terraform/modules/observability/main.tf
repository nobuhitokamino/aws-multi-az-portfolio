# Nginx用CloudWatch Log Group
resource "aws_cloudwatch_log_group" "nginx" {
  name              = var.log_group_name
  retention_in_days = 14

  tags = {
    Name      = var.log_group_name
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

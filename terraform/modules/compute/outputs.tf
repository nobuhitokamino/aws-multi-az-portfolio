output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.web.id
}

output "launch_template_latest_version" {
  description = "Launch Templateの最新バージョン"
  value       = aws_launch_template.web.latest_version
}

output "asg_name" {
  description = "Auto Scaling Group名"
  value       = aws_autoscaling_group.web.name
}

output "asg_arn" {
  description = "Auto Scaling Group ARN"
  value       = aws_autoscaling_group.web.arn
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.web.arn
}

output "alb_dns_name" {
  description = "ALB DNS名"
  value       = aws_lb.web.dns_name
}

output "target_group_arn" {
  description = "ALBのTarget Group ARN"
  value       = aws_lb_target_group.web.arn

  depends_on = [
    aws_lb_listener.https
  ]
}

output "alb_zone_id" {
  description = "ALBのHosted Zone ID"
  value       = aws_lb.web.zone_id
}

output "alb_arn_suffix" {
  description = "ALB ARN Suffix"
  value       = aws_lb.web.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Target Group ARN Suffix"
  value       = aws_lb_target_group.web.arn_suffix
}

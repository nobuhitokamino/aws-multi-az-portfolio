output "nginx_log_group_name" {
  description = "Nginxロググループ名"
  value       = aws_cloudwatch_log_group.nginx.name
}

output "nginx_log_group_arn" {
  description = "NginxロググループARN"
  value       = aws_cloudwatch_log_group.nginx.arn
}

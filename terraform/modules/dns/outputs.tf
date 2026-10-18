output "fqdn" {
  description = "WebサイトのFQDN"
  value       = aws_route53_record.portfolio.fqdn
}

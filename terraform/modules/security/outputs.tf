output "alb_sg_id" {
  description = "ALB用Security Group ID"
  value       = aws_security_group.alb.id
}

output "ec2_sg_id" {
  description = "EC2用Security Group ID"
  value       = aws_security_group.ec2.id
}

output "endpoint_sg_id" {
  description = "Endpoint用Security Group ID"
  value       = aws_security_group.endpoint.id
}

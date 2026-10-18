output "ec2_role_name" {
  description = "EC2用IAM Role名"
  value       = aws_iam_role.ec2.name
}

output "instance_profile_name" {
  description = "EC2用Instance Profile名"
  value       = aws_iam_instance_profile.ec2.name
}

output "instance_profile_arn" {
  description = "EC2用Instance Profile ARN"
  value       = aws_iam_instance_profile.ec2.arn
}

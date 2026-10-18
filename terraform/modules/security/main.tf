# ALB用Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security Group for ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name      = "${var.project_name}-alb-sg"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# EC2用Security Group
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security Group for private EC2"
  vpc_id      = var.vpc_id

  tags = {
    Name      = "${var.project_name}-ec2-sg"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# Interface Endpoint用Security Group
resource "aws_security_group" "endpoint" {
  name        = "${var.project_name}-endpoint-sg"
  description = "Security Group for Interface VPC Endpoints"
  vpc_id      = var.vpc_id

  tags = {
    Name      = "${var.project_name}-endpoint-sg"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# -----------------------------------
# ALB Inbound
# -----------------------------------

# HTTP 80
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

# HTTPS 443
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

# -----------------------------------
# ALB Outbound
# -----------------------------------

# ALB → EC2 HTTP 80
resource "aws_vpc_security_group_egress_rule" "alb_to_ec2" {
  security_group_id = aws_security_group.alb.id

  referenced_security_group_id = aws_security_group.ec2.id

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

# -----------------------------------
# EC2 Inbound
# -----------------------------------

# ALB → EC2 HTTP 80
resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb" {
  security_group_id = aws_security_group.ec2.id

  referenced_security_group_id = aws_security_group.alb.id

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

# -----------------------------------
# EC2 Outbound
# -----------------------------------

# EC2 → Interface Endpoint HTTPS 443
resource "aws_vpc_security_group_egress_rule" "ec2_to_endpoint" {
  security_group_id = aws_security_group.ec2.id

  referenced_security_group_id = aws_security_group.endpoint.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

# EC2 → S3 HTTPS 443
resource "aws_vpc_security_group_egress_rule" "ec2_to_s3" {
  security_group_id = aws_security_group.ec2.id

  prefix_list_id = var.s3_prefix_list_id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

# -----------------------------------
# Interface Endpoint Inbound
# -----------------------------------

# EC2 → Interface Endpoint HTTPS 443
resource "aws_vpc_security_group_ingress_rule" "endpoint_from_ec2" {
  security_group_id = aws_security_group.endpoint.id

  referenced_security_group_id = aws_security_group.ec2.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

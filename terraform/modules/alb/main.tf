# Application Load Balancer
resource "aws_lb" "web" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    var.alb_sg_id
  ]

  subnets = var.public_subnet_ids

  enable_deletion_protection = false

  access_logs {
    bucket  = var.alb_access_logs_bucket_name
    prefix  = "alb"
    enabled = true
  }
  tags = {
    Name      = "${var.project_name}-alb"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# Web用Target Group
resource "aws_lb_target_group" "web" {
  name        = "${var.project_name}-web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  deregistration_delay = 30

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name      = "${var.project_name}-web-tg"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

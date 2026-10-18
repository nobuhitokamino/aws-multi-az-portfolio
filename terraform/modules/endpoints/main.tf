locals {
  endpoint_services = toset([
    "ssm",
    "ssmmessages",
    "logs"
  ])
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.endpoint_services

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = var.subnet_ids

  security_group_ids = [
    var.endpoint_sg_id
  ]

  tags = {
    Name      = "${var.project_name}-${each.key}-endpoint"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

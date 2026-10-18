module "network" {
  source = "../../modules/network"

  project_name = "aws-multi-az-portfolio"
  vpc_cidr     = "10.0.0.0/16"

  public_subnets = {
    "1a" = {
      az   = "ap-northeast-1a"
      cidr = "10.0.1.0/24"
    }

    "1c" = {
      az   = "ap-northeast-1c"
      cidr = "10.0.2.0/24"
    }
  }

  private_subnets = {
    "1a" = {
      az   = "ap-northeast-1a"
      cidr = "10.0.11.0/24"
    }

    "1c" = {
      az   = "ap-northeast-1c"
      cidr = "10.0.12.0/24"
    }
  }
}

module "security" {
  source = "../../modules/security"

  project_name      = "aws-multi-az-portfolio"
  vpc_id            = module.network.vpc_id
  s3_prefix_list_id = module.network.s3_prefix_list_id
}

module "endpoints" {
  source = "../../modules/endpoints"

  project_name = "aws-multi-az-portfolio"
  aws_region   = "ap-northeast-1"

  vpc_id = module.network.vpc_id

  subnet_ids = [
    module.network.private_subnet_ids["1a"],
    module.network.private_subnet_ids["1c"]
  ]

  endpoint_sg_id = module.security.endpoint_sg_id
}

module "iam" {
  source = "../../modules/iam"

  project_name   = "aws-multi-az-portfolio"
  aws_region     = "ap-northeast-1"
  log_group_name = module.observability.nginx_log_group_name
}

module "observability" {
  source = "../../modules/observability"

  project_name   = "aws-multi-az-portfolio"
  log_group_name = "/aws-multi-az-portfolio/dev/nginx"
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

module "compute" {
  source = "../../modules/compute"

  project_name  = "aws-multi-az-portfolio"
  aws_region    = "ap-northeast-1"
  instance_type = "t3.micro"
  ami_id        = data.aws_ssm_parameter.al2023_ami.value

  ec2_sg_id = module.security.ec2_sg_id

  instance_profile_name = module.iam.instance_profile_name

  log_group_name = module.observability.nginx_log_group_name

  private_subnet_ids = [
    module.network.private_subnet_ids["1a"],
    module.network.private_subnet_ids["1c"]
  ]

  target_group_arn = module.alb.target_group_arn

  asg_min_size         = 2
  asg_desired_capacity = 2
  asg_max_size         = 3

  depends_on = [
    module.endpoints,
    module.iam,
    module.observability,
  ]
}

module "alb" {
  source = "../../modules/alb"

  project_name = "aws-multi-az-portfolio"

  vpc_id = module.network.vpc_id

  public_subnet_ids = [
    module.network.public_subnet_ids["1a"],
    module.network.public_subnet_ids["1c"]
  ]

  alb_sg_id = module.security.alb_sg_id

  domain_name = "portfolio.kamino-infra.com"

  alb_access_logs_bucket_name = module.alb_logs.bucket_name

}

module "dns" {
  source = "../../modules/dns"

  hosted_zone_id = "Z01357072PQWQ2VP8L9KP"
  domain_name    = "portfolio.kamino-infra.com"

  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id
}

module "waf" {
  source = "../../modules/waf"

  project_name = "aws-multi-az-portfolio"

  alb_arn = module.alb.alb_arn
}

module "alb_logs" {
  source = "../../modules/alb_logs"

  project_name = "aws-multi-az-portfolio"
  aws_region   = "ap-northeast-1"
}

module "monitoring" {
  source = "../../modules/monitoring"

  project_name = "aws-multi-az-portfolio"
  aws_region   = "ap-northeast-1"

  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  asg_name                = module.compute.asg_name

  alert_email = var.alert_email
}

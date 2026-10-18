variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "ALBを配置するPublic Subnet IDs"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ALB用Security Group ID"
  type        = string
}

variable "domain_name" {
  description = "ALBで使用するドメイン名"
  type        = string
}

variable "alb_access_logs_bucket_name" {
  description = "ALBアクセスログ保存先S3バケット名"
  type        = string
}

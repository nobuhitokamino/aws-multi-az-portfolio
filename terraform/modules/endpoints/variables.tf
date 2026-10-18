variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
}

variable "subnet_ids" {
  description = "Endpointを配置するSubnet ID"
  type        = list(string)
}

variable "endpoint_sg_id" {
  description = "Endpoint用Security Group ID"
  type        = string
}

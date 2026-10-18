variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
}

variable "instance_type" {
  description = "EC2インスタンスタイプ"
  type        = string
  default     = "t3.micro"
}

variable "ec2_sg_id" {
  description = "EC2用Security Group ID"
  type        = string
}

variable "instance_profile_name" {
  description = "EC2用Instance Profile名"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch Logsのロググループ名"
  type        = string
}

variable "private_subnet_ids" {
  description = "ASGでEC2を起動するPrivate Subnet IDs"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ASGに関連付けるTarget Group ARN"
  type        = string
}

variable "ami_id" {
  description = "EC2に使用するAMI ID"
  type        = string
}

variable "asg_min_size" {
  description = "ASGの最小台数"
  type        = number
  default     = 1
}

variable "asg_desired_capacity" {
  description = "ASGの希望台数"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "ASGの最大台数"
  type        = number
  default     = 2
}

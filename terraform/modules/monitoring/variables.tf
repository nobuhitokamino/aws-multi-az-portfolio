variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALBのARN Suffix"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target GroupのARN Suffix"
  type        = string
}

variable "asg_name" {
  description = "Auto Scaling Group名"
  type        = string
}

variable "alert_email" {
  description = "SNS通知先メールアドレス"
  type        = string
  sensitive   = true
}

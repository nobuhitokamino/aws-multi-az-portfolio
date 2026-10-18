variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
}

variable "log_group_name" {
  description = "NginxログのCloudWatch Logsグループ名"
  type        = string
}

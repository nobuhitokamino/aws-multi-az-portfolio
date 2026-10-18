variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "vpc_id" {
  description = "Security Groupを配置するVPC ID"
  type        = string
}

variable "s3_prefix_list_id" {
  description = "S3のプレフィックスリストID"
  type        = string
}

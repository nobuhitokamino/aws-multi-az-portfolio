variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "alb_arn" {
  description = "WAFを関連付けるALB ARN"
  type        = string
}

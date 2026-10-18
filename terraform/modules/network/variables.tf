variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
}

variable "public_subnets" {
  description = "Public Subnetの設定"

  type = map(object({
    az   = string
    cidr = string
  }))
}

variable "private_subnets" {
  description = "Private Subnetの設定"

  type = map(object({
    az   = string
    cidr = string
  }))
}

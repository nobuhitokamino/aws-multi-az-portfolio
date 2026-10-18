variable "hosted_zone_id" {
  description = "既存のRoute 53 Hosted Zone ID"
  type        = string
}

variable "domain_name" {
  description = "Webサイトのドメイン名"
  type        = string
}

variable "alb_dns_name" {
  description = "ALBのDNS名"
  type        = string
}

variable "alb_zone_id" {
  description = "ALBのHosted Zone ID"
  type        = string
}

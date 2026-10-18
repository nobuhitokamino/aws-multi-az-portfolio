# 既存のACM証明書を取得
data "aws_acm_certificate" "portfolio" {
  domain      = var.domain_name
  statuses    = ["ISSUED"]
  most_recent = true
}

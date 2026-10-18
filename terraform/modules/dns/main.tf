# 既存のHosted Zoneを参照
data "aws_route53_zone" "main" {
  zone_id = var.hosted_zone_id
}

# ALB向けAlias Aレコード
resource "aws_route53_record" "portfolio" {
  zone_id = data.aws_route53_zone.main.zone_id

  name = var.domain_name
  type = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = false
  }
}

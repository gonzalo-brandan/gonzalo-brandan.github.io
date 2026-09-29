# Custom domain. The domain is registered at Namecheap, with its nameservers
# pointed at this Route 53 zone (see the route53_nameservers output).

resource "aws_route53_zone" "site" {
  name = var.domain_name
}

# CloudFront only accepts ACM certificates from us-east-1.
resource "aws_acm_certificate" "site" {
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = aws_route53_zone.site.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 300
  allow_overwrite = true
}

# Waits until ACM sees the validation records, which needs the Namecheap
# nameservers to point at Route 53 first.
resource "aws_acm_certificate_validation" "site" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

locals {
  site_hostnames = toset([var.domain_name, "www.${var.domain_name}"])
  alias_records = {
    for pair in setproduct(local.site_hostnames, ["A", "AAAA"]) : "${pair[0]}-${pair[1]}" => {
      name = pair[0]
      type = pair[1]
    }
  }
}

resource "aws_route53_record" "site" {
  for_each = local.alias_records

  zone_id = aws_route53_zone.site.zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

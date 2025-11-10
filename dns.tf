/*
DNS and SSL/TLS Certificate Configuration
*/

locals {
  # Generate all possible parent domains from domain_name
  # For "api.sandbox.example.com", generates: ["sandbox.example.com", "example.com"]
  # For "api.example.com", generates: ["example.com"]
  domain_parts = var.alb_domain_name != null ? split(".", var.alb_domain_name) : []
  possible_zone_names = var.alb_domain_name != null ? [
    for i in range(1, length(local.domain_parts) - 1) :
    join(".", slice(local.domain_parts, i, length(local.domain_parts)))
  ] : []

  # Determine which zone name to look up
  # Priority: explicit route53_zone_name > explicit route53_zone_id > inferred from domain_name
  zone_name_to_lookup = var.alb_route53_zone_name != null ? var.alb_route53_zone_name : (
    var.alb_route53_zone_id == null && length(local.possible_zone_names) > 0 ? local.possible_zone_names[0] : null
  )
}

# Look up Route53 zone by name if needed
# Try the first possible zone name (most specific parent domain)
data "aws_route53_zone" "by_name" {
  count        = local.zone_name_to_lookup != null ? 1 : 0
  name         = local.zone_name_to_lookup
  private_zone = var.alb_route53_zone_private
}

locals {
  # Determine Route53 zone ID (priority: explicit zone_id > looked up by name > null)
  route53_zone_id = var.alb_route53_zone_id != null ? var.alb_route53_zone_id : (
    local.zone_name_to_lookup != null ? data.aws_route53_zone.by_name[0].zone_id : null
  )

  # Determine if DNS is enabled
  dns_enabled = var.alb_enabled && local.route53_zone_id != null && var.alb_domain_name != null

  # Check if certificate will be available (for plan-time evaluation)
  certificate_will_exist = var.alb_certificate_arn != null || (local.dns_enabled && !var.alb_route53_zone_private && var.alb_certificate_create)

  # Determine certificate ARN to use (user-provided > auto-created)
  certificate_arn = (
    var.alb_certificate_arn != null ? var.alb_certificate_arn :
    (local.dns_enabled && !var.alb_route53_zone_private && var.alb_certificate_create ? aws_acm_certificate.main[0].arn : null)
  )
}

# ACM Certificate (only for public zones when certificate_create is true)
resource "aws_acm_certificate" "main" {
  count             = local.dns_enabled && !var.alb_route53_zone_private && var.alb_certificate_create ? 1 : 0
  domain_name       = var.alb_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = local.name
  }
}

# Route53 records for ACM DNS validation (only for public zones when certificate_create is true)
# Use domain names from variables to avoid known-after-apply issues
resource "aws_route53_record" "acm_validation" {
  for_each = local.dns_enabled && !var.alb_route53_zone_private && var.alb_certificate_create ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.route53_zone_id

  lifecycle {
    create_before_destroy = true
  }
}

# ACM Certificate Validation (only for public zones when certificate_create is true)
resource "aws_acm_certificate_validation" "main" {
  count                   = local.dns_enabled && !var.alb_route53_zone_private && var.alb_certificate_create ? 1 : 0
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]

  lifecycle {
    create_before_destroy = true
  }
}

# Route53 A record for primary domain (points to ALB)
resource "aws_route53_record" "main" {
  count   = local.dns_enabled ? 1 : 0
  zone_id = local.route53_zone_id
  name    = var.alb_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main[0].dns_name
    zone_id                = aws_lb.main[0].zone_id
    evaluate_target_health = true
  }
}

# Route53 AAAA record for primary domain (IPv6, points to ALB)
resource "aws_route53_record" "main_ipv6" {
  count   = local.dns_enabled && module.vpc.ipv6_enabled ? 1 : 0
  zone_id = local.route53_zone_id
  name    = var.alb_domain_name
  type    = "AAAA"

  alias {
    name                   = aws_lb.main[0].dns_name
    zone_id                = aws_lb.main[0].zone_id
    evaluate_target_health = true
  }
}

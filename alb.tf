/*
Application Load Balancer
*/

locals {
  # Use public subnets if ALB is public, otherwise use app subnets
  alb_subnets = var.alb_enabled && var.alb_public ? module.vpc.public_subnets_ids : module.vpc.subnets_ids

  # Shared logs bucket needed for ALB access logs and/or the main S3 bucket's server access logs.
  # Regional S3 buckets (storage_regional.tf) can't log here: S3 access log destinations must be in
  # the same Region as the source bucket, and this bucket isn't Region-pinned (it lives in the
  # provider's primary Region, alongside the main bucket).
  logs_bucket_enabled = (var.alb_enabled && var.alb_access_logging_enabled) || local.create_s3_bucket
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  count       = var.alb_enabled ? 1 : 0
  name        = "${local.name}-alb"
  description = "Security group for ${local.name} ALB"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.apn_tags, { Name = "${local.name}-alb" })
}

# Allow inbound HTTP (IPv4)
resource "aws_vpc_security_group_ingress_rule" "alb_http_ipv4" {
  for_each          = var.alb_enabled ? toset(var.alb_ingress_ipv4_cidrs) : []
  security_group_id = aws_security_group.alb[0].id
  description       = "Allow HTTP inbound traffic (IPv4) from ${each.key}"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = each.key
  tags              = local.apn_tags
}

# Allow inbound HTTP (IPv6)
resource "aws_vpc_security_group_ingress_rule" "alb_http_ipv6" {
  for_each          = var.alb_enabled && module.vpc.ipv6_enabled ? toset(var.alb_ingress_ipv6_cidrs) : []
  security_group_id = aws_security_group.alb[0].id
  description       = "Allow HTTP inbound traffic (IPv6) from ${each.key}"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv6         = each.key
  tags              = local.apn_tags
}

# Allow inbound HTTPS (IPv4, only if certificate is provided)
resource "aws_vpc_security_group_ingress_rule" "alb_https_ipv4" {
  for_each          = var.alb_enabled && local.certificate_will_exist ? toset(var.alb_ingress_ipv4_cidrs) : []
  security_group_id = aws_security_group.alb[0].id
  description       = "Allow HTTPS inbound traffic (IPv4) from ${each.key}"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.key
  tags              = local.apn_tags
}

# Allow inbound HTTPS (IPv6, only if certificate is provided)
resource "aws_vpc_security_group_ingress_rule" "alb_https_ipv6" {
  for_each          = var.alb_enabled && local.certificate_will_exist && module.vpc.ipv6_enabled ? toset(var.alb_ingress_ipv6_cidrs) : []
  security_group_id = aws_security_group.alb[0].id
  description       = "Allow HTTPS inbound traffic (IPv6) from ${each.key}"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv6         = each.key
  tags              = local.apn_tags
}

# Allow outbound to ECS service
resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  count                        = var.alb_enabled ? 1 : 0
  security_group_id            = aws_security_group.alb[0].id
  description                  = "Allow traffic to ECS service"
  from_port                    = local.port
  to_port                      = local.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.server.security_group_id
  tags                         = local.apn_tags
}

# Allow inbound from ALB to ECS service
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  count                        = var.alb_enabled ? 1 : 0
  security_group_id            = module.server.security_group_id
  description                  = "Allow traffic from ALB"
  from_port                    = local.port
  to_port                      = local.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb[0].id
  tags                         = local.apn_tags
}

# Application Load Balancer
resource "aws_lb" "main" {
  count                      = var.alb_enabled ? 1 : 0
  name                       = local.name
  internal                   = !var.alb_public
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb[0].id]
  subnets                    = local.alb_subnets
  enable_deletion_protection = var.deletion_protection
  enable_http2               = true
  idle_timeout               = var.alb_idle_timeout
  ip_address_type            = module.vpc.ipv6_enabled ? "dualstack" : "ipv4"
  drop_invalid_header_fields = true

  dynamic "access_logs" {
    for_each = var.alb_enabled && var.alb_access_logging_enabled ? [1] : []
    content {
      bucket  = aws_s3_bucket.logs[0].id
      prefix  = local.name
      enabled = true
    }
  }

  tags = merge(local.apn_tags, { Name = local.name })
}

# Target Group
resource "aws_lb_target_group" "main" {
  count                             = var.alb_enabled ? 1 : 0
  name                              = local.name
  port                              = local.port
  protocol                          = "HTTP"
  vpc_id                            = module.vpc.vpc_id
  target_type                       = "ip"
  load_balancing_algorithm_type     = "weighted_random"
  load_balancing_anomaly_mitigation = "on"
  health_check {
    path = "/health"
  }
  tags = merge(local.apn_tags, { Name = local.name })
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  count             = var.alb_enabled ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 80
  protocol          = "HTTP"
  tags              = local.apn_tags

  # If HTTPS is enabled, redirect HTTP to HTTPS, otherwise forward to target group
  dynamic "default_action" {
    for_each = local.certificate_will_exist ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = !local.certificate_will_exist ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.main[0].arn
    }
  }
}

# HTTPS Listener (only if certificate is provided)
resource "aws_lb_listener" "https" {
  count             = var.alb_enabled && local.certificate_will_exist ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.alb_ssl_policy
  certificate_arn   = local.certificate_arn
  tags              = local.apn_tags

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }
}

# Shared S3 bucket for ALB access logs and/or the main bucket's server access logs (storage.tf).
# ELB log delivery only supports SSE-S3 (not SSE-KMS), so this bucket cannot reuse the module's
# KMS-encrypted application bucket and must use its own default encryption.
resource "aws_s3_bucket" "logs" {
  count         = local.logs_bucket_enabled ? 1 : 0
  bucket        = "${local.name}-logs"
  force_destroy = !var.deletion_protection
  tags          = merge(local.apn_tags, { Name = "${local.name}-logs" })
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count                   = local.logs_bucket_enabled ? 1 : 0
  bucket                  = aws_s3_bucket.logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count  = local.logs_bucket_enabled ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count      = local.logs_bucket_enabled ? 1 : 0
  bucket     = aws_s3_bucket.logs[0].id
  depends_on = [aws_s3_bucket_versioning.logs]

  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = var.cloudwatch_logs_retention_in_days
    }
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  count  = local.logs_bucket_enabled ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# Grants ELB log delivery (region-agnostic 'logdelivery.elasticloadbalancing.amazonaws.com' service
# principal, recommended over the legacy per-Region ELB account ID policy) and/or S3 server access
# log delivery ('logging.s3.amazonaws.com') permission to write to this bucket. SSE-S3 only, matching
# the bucket's own encryption above (ELB log delivery doesn't support SSE-KMS destinations).
data "aws_iam_policy_document" "logs" {
  count = local.logs_bucket_enabled ? 1 : 0

  dynamic "statement" {
    for_each = var.alb_enabled && var.alb_access_logging_enabled ? [1] : []
    content {
      sid    = "AWSLogDeliveryWrite"
      effect = "Allow"
      principals {
        type        = "Service"
        identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
      }
      actions   = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.logs[0].arn}/${local.name}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    }
  }

  dynamic "statement" {
    for_each = local.create_s3_bucket ? [1] : []
    content {
      sid    = "S3ServerAccessLogsPolicy"
      effect = "Allow"
      principals {
        type        = "Service"
        identifiers = ["logging.s3.amazonaws.com"]
      }
      actions   = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.logs[0].arn}/s3-access-logs/*"]
      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
      condition {
        test     = "ArnLike"
        variable = "aws:SourceArn"
        values   = [aws_s3_bucket.main[0].arn]
      }
    }
  }

  statement {
    sid    = "EnforceTLS"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.logs[0].arn, "${aws_s3_bucket.logs[0].arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  count  = local.logs_bucket_enabled ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id
  policy = data.aws_iam_policy_document.logs[0].json
}

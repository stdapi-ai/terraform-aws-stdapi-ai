/*
Application Load Balancer
*/

# Proxy headers trusted from a peer this module cannot name: only the ALB's own subnets can be
# derived, so enabling them anywhere else leaves the server on its default of trusting every
# peer. A warning, not an error, because the combination applies today and the operator may have
# a proxy in front that this module knows nothing about.
check "proxy_headers_name_their_peer" {
  assert {
    condition     = !local.enable_proxy_headers || local.proxy_trusted_hosts_declared != null
    error_message = "enable_proxy_headers is on without an ALB to derive the trusted peer from, so the server falls back to trusting X-Forwarded-* from every peer that can reach it. Set proxy_trusted_hosts to the CIDR blocks of your proxy."
  }
}

locals {
  # Use public subnets if ALB is public, otherwise use app subnets
  alb_subnets = var.alb_enabled && var.alb_public ? module.vpc.public_subnets_ids : module.vpc.subnets_ids

  # CIDR blocks (IPv4 + IPv6) of the subnets the ALB nodes live in; used to trust
  # only the ALB as the X-Forwarded-* peer when proxy headers are auto-enabled.
  alb_subnets_cidr_blocks = var.alb_public ? concat(
    module.vpc.public_subnets_cidr_blocks, module.vpc.public_subnets_ipv6_cidr_blocks
    ) : concat(
    module.vpc.subnets_cidr_blocks, module.vpc.subnets_ipv6_cidr_blocks
  )

  # Whether the server trusts X-Forwarded-* at all. An explicit setting wins, including an
  # explicit false: only an unset value is auto-enabled, and only for an ALB whose client IP the
  # deployment asked to log.
  enable_proxy_headers = (
    var.enable_proxy_headers != null ? var.enable_proxy_headers :
    (var.alb_enabled && var.log_client_ip == true)
  )

  # Trusted peers, before the address families the server actually sees are covered. Tied to the
  # resolved value above rather than to log_client_ip: trusting the headers without naming a peer
  # leaves the server on its own default of "*", where anything that can reach the task can forge
  # X-Forwarded-For and choose the client IP the deployment records.
  proxy_trusted_hosts_declared = var.proxy_trusted_hosts != null ? var.proxy_trusted_hosts : (
    (local.enable_proxy_headers && var.alb_enabled) ? local.alb_subnets_cidr_blocks : null
  )

  # With IPv6 on, the server binds a dual-stack socket (GRANIAN_HOST below), and the
  # kernel hands it an IPv4 peer as an IPv4-mapped address (::ffff:10.0.1.5). That
  # belongs to no IPv4 network, so every IPv4 entry also needs its mapped equivalent
  # (an IPv4 /16 is a /112 once the 96-bit mapping prefix is counted) or the ALB stops
  # being a trusted peer and X-Forwarded-For is silently ignored.
  proxy_trusted_hosts = (
    local.proxy_trusted_hosts_declared == null || !module.vpc.ipv6_enabled
    ? local.proxy_trusted_hosts_declared
    : distinct(concat(local.proxy_trusted_hosts_declared, [
      for host in local.proxy_trusted_hosts_declared :
      "::ffff:${split("/", host)[0]}/${96 + tonumber(try(split("/", host)[1], "32"))}"
      if can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+(/[0-9]{1,2})?$", host))
    ]))
  )

  # Every way a client can be made to prove who it is: an API key from any of its sources, an
  # Amazon Cognito user pool, or a tenant API key. Matches what the server counts as an enabled
  # authentication method at startup; with none of them it accepts every request.
  authentication_configured = (
    var.api_key != null ||
    var.api_key_create ||
    var.api_key_ssm_parameter != null ||
    var.api_key_secretsmanager_secret != null ||
    var.aws_cognito_user_pool_id != null ||
    length(var.tenants) > 0
  )

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

  tags = merge(local.tags, { Name = "${local.name}-alb" })
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
  tags              = local.tags
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
  tags              = local.tags
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
  tags              = local.tags
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
  tags              = local.tags
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
  tags                         = local.tags
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
  tags                         = local.tags
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

  tags = merge(local.tags, { Name = local.name })

  lifecycle {
    # An internet-facing load balancer in front of a server that authenticates nobody is an open
    # LLM gateway billed to this account, and nothing else in the plan says so: the server only
    # records a startup warning, and answers every request meanwhile.
    precondition {
      condition     = !var.alb_public || local.authentication_configured
      error_message = "alb_public = true requires an authentication method: set api_key_create = true, or one of api_key / api_key_ssm_parameter / api_key_secretsmanager_secret, or aws_cognito_user_pool_id, or declare tenants. Without one the server accepts every request that reaches it, and this load balancer puts it on the internet."
    }
  }
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
  tags = merge(local.tags, { Name = local.name })
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  count             = var.alb_enabled ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 80
  protocol          = "HTTP"
  tags              = local.tags

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
  tags              = local.tags

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
  tags          = merge(local.tags, { Name = "${local.name}-logs" })
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

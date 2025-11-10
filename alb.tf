/*
Application Load Balancer
*/

locals {
  # Use public subnets if ALB is public, otherwise use app subnets
  alb_subnets = var.alb_enabled && var.alb_public ? module.vpc.public_subnets_ids : module.vpc.subnets_ids
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  count       = var.alb_enabled ? 1 : 0
  name        = "${local.name}-alb"
  description = "Security group for ${local.name} ALB"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${local.name}-alb"
  }
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

  tags = {
    Name = local.name
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
  tags = {
    Name = local.name
  }
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  count             = var.alb_enabled ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 80
  protocol          = "HTTP"

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
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }
}

# CloudWatch Log Group for ALB Access Logs
resource "aws_cloudwatch_log_group" "alb" {
  count             = var.alb_enabled ? 1 : 0
  name              = "/aws/elasticloadbalancing/${local.name}"
  retention_in_days = var.cloudwatch_logs_retention_in_days
  kms_key_id        = module.kms_key.arn
  depends_on        = [module.kms_key.policy_dependency]
}

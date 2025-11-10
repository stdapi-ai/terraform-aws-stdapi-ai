/*
AWS WAF WebACL with AWS Managed Rules
*/

resource "aws_wafv2_web_acl" "main" {
  count       = var.alb_enabled && var.alb_waf_enabled ? 1 : 0
  name        = local.name
  description = "WAF for ${local.name} ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed Rule: Core Rule Set (CRS)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"

        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }

        rule_action_override {
          name = "GenericLFI_BODY"
          action_to_use {
            count {}
          }
        }

        rule_action_override {
          name = "GenericRFI_BODY"
          action_to_use {
            count {}
          }
        }

        rule_action_override {
          name = "CrossSiteScripting_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule: Linux specific
  rule {
    name     = "AWSManagedRulesLinuxRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesLinuxRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-linux"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule: Amazon IP Reputation List
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule: Anonymous IP List
  dynamic "rule" {
    for_each = var.alb_waf_block_anonymous_ips ? [1] : []
    content {
      name     = "AWSManagedRulesAnonymousIpList"
      priority = 4

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = "AWSManagedRulesAnonymousIpList"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name}-anonymous-ips"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rate Limiting Rule
  dynamic "rule" {
    for_each = var.alb_waf_rate_limit != null ? [1] : []
    content {
      name     = "RateLimitRule"
      priority = 10

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.alb_waf_rate_limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name}-rate-limit"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = local.name
  }
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "main" {
  count        = var.alb_enabled && var.alb_waf_enabled ? 1 : 0
  resource_arn = aws_lb.main[0].arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}

# CloudWatch Log Group for WAF Logs
resource "aws_cloudwatch_log_group" "waf" {
  count             = var.alb_enabled && var.alb_waf_enabled && var.alb_waf_logging_enabled ? 1 : 0
  name              = "aws-waf-logs-${local.name}"
  retention_in_days = var.cloudwatch_logs_retention_in_days
  kms_key_id        = module.kms_key.arn
  depends_on        = [module.kms_key.policy_dependency]
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count                   = var.alb_enabled && var.alb_waf_enabled && var.alb_waf_logging_enabled ? 1 : 0
  resource_arn            = aws_wafv2_web_acl.main[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
}

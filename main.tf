/*
Common config
*/

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.name_prefix}-${random_id.main.hex}"
  name        = "${local.name_prefix}-${data.aws_region.current.region}"
  name_log    = "${local.name}-logs"
  ecs_service = true
  port        = 8000

  # AWS Marketplace ECR configuration
  marketplace_ecr_repository_url = "709825985650.dkr.ecr.us-east-1.amazonaws.com/j-goutin/stdapi.ai"
  container_image                = "${local.marketplace_ecr_repository_url}:${var.version_to_deploy}-${var.cpu_architecture == "ARM64" ? "arm64" : "amd64"}"

  # AWS PRM attribution tags
  apn_product_code = "72gxmztpjz2hm5qnkkg0iiazo"
  apn_tags         = { "aws-apn-id" = "pc:${local.apn_product_code}" }
}

# Application ID used in names

resource "random_id" "main" {
  byte_length = 4
}

# API Key generation

resource "random_password" "api_key" {
  count   = var.api_key_create ? 1 : 0
  length  = 64
  special = false
}

# Realtime API client secret signing key

locals {
  # The server derives the key from the API key, and falls back to a per-process
  # random value when no API key is configured, which makes an ephemeral client
  # secret minted by one task fail on any other task. Generate one instead, so
  # the key survives scaling out and task replacement.
  create_realtime_client_secret_key = (
    var.realtime_client_secret_key == null &&
    var.api_key == null &&
    !var.api_key_create &&
    var.api_key_ssm_parameter == null &&
    var.api_key_secretsmanager_secret == null
  )

  realtime_client_secret_key = var.realtime_client_secret_key != null ? var.realtime_client_secret_key : (
    local.create_realtime_client_secret_key ? random_password.realtime_client_secret_key[0].result : null
  )
}

resource "random_password" "realtime_client_secret_key" {
  count   = local.create_realtime_client_secret_key ? 1 : 0
  length  = 64
  special = false
}

data "aws_iam_policy_document" "log_kms_policy" {
  statement {
    sid = "Allow ${local.name} applications logs"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [module.kms_key.arn]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.name}*",
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/elasticloadbalancing/${local.name}*",
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/wafv2/${local.name}*",
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-${local.name}*"
      ]
    }
  }
}

# CloudWatch Log Query Definition for application logs
resource "aws_cloudwatch_query_definition" "main" {
  name = local.name_log
  log_group_names = [
    module.server.cloudwatch_log_groups_names["main"]
  ]
  query_string = <<EOF
fields @timestamp, level, type, event, fqdn, ipv, @message
| sort @timestamp desc
| limit 100
EOF
}

# KMS key

module "kms_key" {
  source  = "JGoutin/kms-key/aws"
  version = "~> 1.2"

  id          = var.kms_key_id
  name_prefix = local.name
  tags        = local.apn_tags
  policy_documents_json = concat(
    [
      data.aws_iam_policy_document.log_kms_policy.json,
    ],
    module.vpc.kms_policy_documents_json,
    module.server.kms_policy_documents_json,
  )
}

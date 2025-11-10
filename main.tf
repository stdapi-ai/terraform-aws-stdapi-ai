/*
Common config
*/

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.name_prefix}-${random_id.main.hex}"
  name        = "${local.name_prefix}-${data.aws_region.current.name}"
  name_log    = "${local.name}-logs"
  ecs_service = true
  port        = 8000

  # AWS Marketplace ECR configuration
  marketplace_ecr_repository_url = "709825985650.dkr.ecr.us-east-1.amazonaws.com/j-goutin/stdapi.ai"
  container_image                = "${local.marketplace_ecr_repository_url}:${var.version_to_deploy}-${var.cpu_architecture == "ARM64" ? "arm64" : "amd64"}"
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

data "aws_iam_policy_document" "log_kms_policy" {
  statement {
    sid = "Allow ${local.name} applications logs"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
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
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.name}*",
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/elasticloadbalancing/${local.name}*",
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/wafv2/${local.name}*",
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-${local.name}*"
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
  version = "~> 1.0"

  id          = var.kms_key_id
  name_prefix = local.name
  policy_documents_json = concat(
    [
      data.aws_iam_policy_document.log_kms_policy.json,
    ],
    module.vpc.kms_policy_documents_json,
    module.server.kms_policy_documents_json,
  )
}

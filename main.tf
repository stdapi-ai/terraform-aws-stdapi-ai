/*
Common config
*/

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  name_prefix = "${var.name_prefix}-${random_id.main.hex}"
  name        = "${local.name_prefix}-${data.aws_region.current.region}"
  name_log    = "${local.name}-logs"
  ecs_service = true
  port        = 8000

  # The public image by default; an operator mirror of it in their own Amazon ECR repository when
  # set, which is pulled through the ECR VPC endpoints and so needs no internet access.
  container_image_repository_url = coalesce(var.container_image_repository_url, "ghcr.io/stdapi-ai/stdapi.ai-community")
  container_image                = "${local.container_image_repository_url}:${var.version_to_deploy}"

  # The region of the mirror repository: a pull from another region cannot go through the VPC
  # endpoints, which are regional.
  container_image_regions = var.container_image_repository_url != null ? [split(".", var.container_image_repository_url)[3]] : []

  # A tag of the module's own keeps the Security Hub tagging controls passing when var.tags is
  # empty; var.tags is merged last, so an operator can override its value.
  tags = merge({ "stdapi-ai.deployment" = local.name_prefix }, var.tags)
}

# var.name_prefix is bounded against the shortest region name AWS publishes, because a variable
# validation cannot read the region. Here it can, so the two names that bind report the ceiling this
# deployment actually has. A warning rather than an error: the bound moves with the region, and an
# operator who reads it can shorten the prefix before the apply stops halfway through creating the
# deployment, which is where the provider's own length checks would otherwise fire.
check "name_prefix_fits_the_deployment_region" {
  # Counted rather than measured: local.name carries random_id.main.hex, unknown on a first plan,
  # which would leave the assertion itself unknown. The 10 characters it adds are constant.
  assert {
    condition     = length(var.name_prefix) <= 40 - 2 * length(data.aws_region.current.region)
    error_message = "name_prefix is ${length(var.name_prefix)} characters, over the ${40 - 2 * length(data.aws_region.current.region)} region ${data.aws_region.current.region} leaves: the VPC flow log IAM role name repeats the region and caps at IAM's 64 characters."
  }

  assert {
    condition     = !var.alb_enabled || length(var.name_prefix) <= 22 - length(data.aws_region.current.region)
    error_message = "name_prefix is ${length(var.name_prefix)} characters, over the ${22 - length(data.aws_region.current.region)} region ${data.aws_region.current.region} leaves: the load balancer and its target group cap at 32 characters."
  }
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
  version = "~> 1.2, >= 1.2.2"

  id          = var.kms_key_id
  name_prefix = local.name
  tags        = local.tags
  policy_documents_json = concat(
    [
      data.aws_iam_policy_document.log_kms_policy.json,
    ],
    module.vpc.kms_policy_documents_json,
    module.server.kms_policy_documents_json,
  )
}

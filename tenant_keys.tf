/*
Tenant API keys

Each entry of var.tenants becomes one tenant record in the shared DynamoDB table: its
identity, its model and endpoint restrictions, and its lifecycle. That is the whole of what
Terraform owns.

The key secret is deliberately not created here. Terraform state is plaintext, shows in plan
output, and gets committed, shared and backed up — a bearer credential must never land in it.
The server mints the secret for every declared tenant, records only a salted hash in the
table, and delivers the full key once through an SSM SecureString parameter under
local.tenant_key_ssm_parameter_prefix (see the tenant_keys module output). Retrieve it, hand
it to the tenant, then delete the parameter.
*/

locals {
  tenant_keys_enabled = length(var.tenants) > 0

  # The reported TENANT_API_KEYS setting alone: tenant_api_keys lets an operator report the
  # feature as enabled or disabled independently of tenants, for example when tenant records are
  # written to the shared table by something other than this module. The DynamoDB table items
  # below, and the SSM/KMS delivery grants further down, stay scoped to tenants regardless.
  tenant_api_keys_enabled = var.tenant_api_keys != null ? var.tenant_api_keys : local.tenant_keys_enabled

  # One prefix per deployment: the IAM grant below and the server's delivery writes are both
  # scoped to it, so two deployments in one account can never read each other's tenant keys. This
  # follows tenant_api_keys_enabled rather than tenants being non-empty: the prefix and the grant
  # it feeds must exist whenever the server validates tenant keys, whether or not Terraform
  # declared any tenant itself. tenant_key_ssm_parameter_prefix overrides the derived default;
  # both flow into the same IAM grant, so a custom prefix is never wider than the one this module
  # derives.
  tenant_key_ssm_parameter_prefix = local.tenant_api_keys_enabled ? coalesce(var.tenant_key_ssm_parameter_prefix, "/${local.name_prefix}/tenant-keys") : null

  # KMS key encrypting the SSM parameters tenant keys are delivered through: this deployment's
  # own key by default, or one supplied through tenant_key_ssm_kms_key_id. Computed unconditionally
  # since it is only ever read behind tenant_api_keys_enabled elsewhere.
  tenant_key_ssm_kms_key_arn = coalesce(var.tenant_key_ssm_kms_key_id, module.kms_key.arn)

  # Cross-account roles the tenants declared: the sts:AssumeRole grant derives from them, so the
  # IAM statement covers exactly the declared roles regardless of tenant_aws_credentials below.
  tenant_role_arns = distinct(compact([for _, tenant in var.tenants : tenant.aws_role_arn]))

  # The reported TENANT_AWS_CREDENTIALS setting alone: tenant_aws_credentials lets an operator
  # report the feature as enabled or disabled independently of tenants. The sts:AssumeRole grant
  # in server.tf stays scoped to the roles tenants actually declares: there is no ARN to grant
  # against otherwise.
  tenant_aws_credentials_enabled = var.tenant_aws_credentials != null ? var.tenant_aws_credentials : length(local.tenant_role_arns) > 0

  # A guardrail can also arrive on a model alias, which the server refuses exactly as it refuses the
  # deployment-wide one. An alias is either a model ID or an object configuring the request, and
  # var.model_aliases is any-typed, so each entry is probed rather than typed.
  tenant_alias_guardrail = var.model_aliases == null ? false : anytrue([
    for _, alias in var.model_aliases :
    try(alias.guardrail_id, null) != null || try(alias.guardrail_identifier, null) != null
  ])
}

# The public key identifier, embedded in the key as "sk-std-<key id>-<secret>". Not a secret:
# it is safe in state, logs and usage records, which is exactly why Terraform may generate it
# while the secret stays server-side.
resource "random_string" "tenant_key_id" {
  for_each = var.tenants

  length  = 16
  special = false
}

resource "aws_dynamodb_table_item" "tenant" {
  for_each = var.tenants

  # The table name is composed rather than read from the resource (see dynamodb.tf), so the
  # ordering the reference used to carry has to be declared.
  depends_on = [aws_dynamodb_table.main]

  region     = local.dynamodb_region
  table_name = local.dynamodb_table_name
  hash_key   = "pk"
  range_key  = "sk"

  # The record layout the server reads: schema 1, scope attributes present only when set —
  # an absent list restricts nothing, an explicitly empty one allows nothing.
  item = jsonencode(merge(
    {
      pk       = { S = "TENANT" }
      sk       = { S = "tenant#${random_string.tenant_key_id[each.key].result}" }
      schema   = { N = "1" }
      name     = { S = each.key }
      disabled = { BOOL = each.value.disabled }
    },
    each.value.models_allow == null ? {} : {
      models_allow = { L = [for pattern in each.value.models_allow : { S = pattern }] }
    },
    each.value.models_deny == null ? {} : {
      models_deny = { L = [for pattern in each.value.models_deny : { S = pattern }] }
    },
    each.value.endpoints_allow == null ? {} : {
      endpoints_allow = { L = [for pattern in each.value.endpoints_allow : { S = pattern }] }
    },
    each.value.endpoints_deny == null ? {} : {
      endpoints_deny = { L = [for pattern in each.value.endpoints_deny : { S = pattern }] }
    },
    each.value.aws_role_arn == null ? {} : {
      aws_role_arn = { S = each.value.aws_role_arn }
    },
  ))

  lifecycle {
    precondition {
      # Mirrors the server's own startup refusal, at plan time: a guardrail of this
      # account cannot be evaluated by a tenant's principal, so tenant-signed
      # requests would run unguarded.
      condition     = length(local.tenant_role_arns) == 0 || (var.aws_bedrock_guardrail_identifier == null && !local.tenant_alias_guardrail)
      error_message = "A tenants entry declaring aws_role_arn cannot be combined with Amazon Bedrock Guardrails, whether from aws_bedrock_guardrail_identifier or from a model_aliases entry carrying guardrail_id: Guardrails have no cross-account path, so tenant-signed requests would run unguarded."
    }
  }
}

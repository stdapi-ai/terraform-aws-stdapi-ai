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

  # One prefix per deployment: the IAM grant below and the server's delivery writes are both
  # scoped to it, so two deployments in one account can never read each other's tenant keys.
  tenant_key_ssm_parameter_prefix = local.tenant_keys_enabled ? "/${local.name_prefix}/tenant-keys" : null
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
  ))

  lifecycle {
    precondition {
      condition     = local.dynamodb_table_name != null
      error_message = "tenants requires the shared DynamoDB table holding the tenant records: set aws_dynamodb_table or aws_dynamodb_table_create."
    }
  }
}

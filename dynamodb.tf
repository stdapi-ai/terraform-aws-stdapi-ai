/*
Shared DynamoDB table

A single on-demand table backing internal server state that does not belong in S3 or in the
task's own memory. The table is not configured: it appears with the first feature that needs
it and with nothing else, so a deployment that uses neither is billed for no table. An
operator who manages this table outside Terraform can point at it with aws_dynamodb_table
instead, in which case this module creates nothing.
*/

locals {
  # The two features whose state outlives a task: tenant API keys being enabled, not merely
  # tenants being non-empty, since an operator can force the feature on against records written
  # by something other than this module; and the models list one server publishes for the others
  # to read. Only creates a table of its own when the operator has not supplied one through
  # aws_dynamodb_table.
  create_dynamodb_table = var.aws_dynamodb_table == null && (local.tenant_api_keys_enabled || var.model_cache_shared == true)

  # A DynamoDB table is a regional resource with no failover, like the S3 vector bucket, so it
  # lives where the deployment does by default: state held anywhere else would add a
  # cross-region round trip to every request that reads it. aws_dynamodb_region overrides this
  # for both the table this module creates and one supplied through aws_dynamodb_table.
  dynamodb_region = var.aws_dynamodb_region != null ? var.aws_dynamodb_region : data.aws_region.current.region

  # Priority: user-specified table > auto-created table > null (no table)
  dynamodb_table_name = var.aws_dynamodb_table != null ? var.aws_dynamodb_table : (
    local.create_dynamodb_table ? "${local.name_prefix}-table-${local.dynamodb_region}" : null
  )

  # Name and ARN are composed rather than read back from the resource. For the module's own
  # table this also avoids a dependency cycle: the table is encrypted with the project key,
  # whose policy is assembled from the ECS module's own statements, so a reference from the ECS
  # module's configuration back to the table would close that loop. Composing them from the name
  # and region is exact either way: the module's own table always lives there, and a supplied one
  # is only usable if it does too.
  dynamodb_table_arn = local.dynamodb_table_name != null ? "arn:${data.aws_partition.current.partition}:dynamodb:${local.dynamodb_region}:${data.aws_caller_identity.current.account_id}:table/${local.dynamodb_table_name}" : null
}

resource "aws_dynamodb_table" "main" {
  count  = local.create_dynamodb_table ? 1 : 0
  region = local.dynamodb_region
  name   = local.dynamodb_table_name

  lifecycle {
    precondition {
      # This resource only exists while the module creates the table, which is exactly when the
      # check below applies: the table is encrypted with the deployment's own regional KMS key
      # (server_side_encryption below), and a KMS key cannot encrypt a table in another region. A
      # table supplied through aws_dynamodb_table carries no such constraint and is never planned
      # here, so it can live in whatever region aws_dynamodb_region names.
      condition     = var.aws_dynamodb_region == null || var.aws_dynamodb_region == data.aws_region.current.region
      error_message = "aws_dynamodb_region cannot differ from this deployment's own region while the module creates the table: it is encrypted with the deployment's own regional KMS key, which cannot encrypt a table in another region. Either leave aws_dynamodb_region unset, or supply an existing table in that region through aws_dynamodb_table."
    }
  }

  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  # Derived from what the table holds, not from var.deletion_protection. Follows
  # tenant_api_keys_enabled rather than tenants being non-empty: with tenant API keys enabled the
  # table holds the secret hashes and salts the server minted, whether Terraform declared the
  # tenant that owns them or an operator forced the feature on against records written by
  # something other than this module, and either way that data exists nowhere else. Losing the
  # table invalidates every tenant credential with no way back, so Security Hub's DynamoDB.6 is
  # what the table gets. Holding only the shared models list it is a pure cache -- manifest,
  # shards and lease, all already TTL'd and all rebuilt by the next discovery sweep -- so
  # protecting it would buy nothing and would leave a destroy that cannot complete.
  deletion_protection_enabled = local.tenant_api_keys_enabled

  # The deployment's own KMS key, as every other resource this module encrypts. DynamoDB uses
  # grants for ongoing access, so the ECS task role needs no KMS permission of its own for
  # table reads and writes.
  server_side_encryption {
    enabled     = true
    kms_key_arn = module.kms_key.arn
  }

  tags = merge(local.tags, { Name = local.dynamodb_table_name })
}

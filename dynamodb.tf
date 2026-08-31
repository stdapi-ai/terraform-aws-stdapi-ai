/*
Shared DynamoDB table

A single on-demand table backing internal server state that does not belong in S3 or in the
task's own memory. The table is not configured: it appears with the first feature that needs
it and with nothing else, so a deployment that uses neither is billed for no table.
*/

locals {
  # The two features whose state outlives a task: the tenant records Terraform writes, and the
  # models list one server publishes for the others to read.
  create_dynamodb_table = local.tenant_keys_enabled || var.model_cache_shared == true

  # A DynamoDB table is a regional resource with no failover, like the S3 vector bucket, so it
  # lives where the deployment does: state held anywhere else would only add a cross-region
  # round trip to every request that reads it.
  dynamodb_region = data.aws_region.current.region

  dynamodb_table_name = local.create_dynamodb_table ? "${local.name_prefix}-table-${local.dynamodb_region}" : null

  # Name and ARN are composed rather than read back from the resource. The table is encrypted
  # with the project key, whose policy is assembled from the ECS module's own statements, so a
  # reference from the ECS module's configuration back to the table would close that loop into
  # a dependency cycle. Composing them is exact: the module owns the table, in this account and
  # in this region.
  dynamodb_table_arn = local.create_dynamodb_table ? "arn:${data.aws_partition.current.partition}:dynamodb:${local.dynamodb_region}:${data.aws_caller_identity.current.account_id}:table/${local.dynamodb_table_name}" : null
}

resource "aws_dynamodb_table" "main" {
  count = local.create_dynamodb_table ? 1 : 0
  name  = local.dynamodb_table_name

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

  # Derived from what the table holds, not from var.deletion_protection. With tenant API keys on it
  # holds the secret hashes and salts the server minted, which exist nowhere else: losing the table
  # invalidates every tenant credential with no way back, so Security Hub's DynamoDB.6 is what the
  # table gets. Holding only the shared models list it is a pure cache -- manifest, shards and lease,
  # all already TTL'd and all rebuilt by the next discovery sweep -- so protecting it would buy
  # nothing and would leave a destroy that cannot complete.
  deletion_protection_enabled = local.tenant_keys_enabled

  # The deployment's own KMS key, as every other resource this module encrypts. DynamoDB uses
  # grants for ongoing access, so the ECS task role needs no KMS permission of its own for
  # table reads and writes.
  server_side_encryption {
    enabled     = true
    kms_key_arn = module.kms_key.arn
  }

  tags = merge(local.tags, { Name = local.dynamodb_table_name })
}

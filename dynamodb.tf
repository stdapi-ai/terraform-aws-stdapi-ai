/*
Shared DynamoDB table

A single on-demand table backing internal server state that does not belong in S3 or in the
task's own memory. Off by default; landed ahead of the features that will use it.
*/

locals {
  # Create table only if enabled and no user-provided table
  create_dynamodb_table = var.aws_dynamodb_table_create && var.aws_dynamodb_table == null

  # Region holding the table, defaulting to the region this module is deployed in. Like the S3
  # vector bucket, this is a single regional resource with no failover, so it is always resolved
  # to a concrete region.
  dynamodb_region = var.aws_dynamodb_region != null ? var.aws_dynamodb_region : data.aws_region.current.region

  dynamodb_table_created_name = "${local.name_prefix}-table-${local.dynamodb_region}"

  # Determine the table name to use for the application
  # Priority: user-specified table > auto-created table > null (no table)
  dynamodb_table_name = var.aws_dynamodb_table != null ? var.aws_dynamodb_table : (
    local.create_dynamodb_table ? aws_dynamodb_table.main[0].name : null
  )

  # Table ARN built from name, account and region, so it resolves whether this module created the
  # table or an operator points at an existing one.
  dynamodb_table_arn = local.dynamodb_table_name != null ? "arn:${data.aws_partition.current.partition}:dynamodb:${local.dynamodb_region}:${data.aws_caller_identity.current.account_id}:table/${local.dynamodb_table_name}" : null
}

resource "aws_dynamodb_table" "main" {
  count  = local.create_dynamodb_table ? 1 : 0
  region = local.dynamodb_region
  name   = local.dynamodb_table_created_name

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

  deletion_protection_enabled = true

  # Unset (null) leaves the table on the AWS owned key: free, always-on encryption that needs no
  # key policy of its own. Set aws_dynamodb_table_kms_key_arn to use a customer managed key instead.
  server_side_encryption {
    enabled     = var.aws_dynamodb_table_kms_key_arn != null
    kms_key_arn = var.aws_dynamodb_table_kms_key_arn
  }

  tags = merge(local.apn_tags, { Name = local.dynamodb_table_created_name })
}

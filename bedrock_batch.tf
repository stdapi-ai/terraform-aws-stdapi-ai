/*
Amazon Bedrock batch inference service role

Batch inference needs two policies: the server's own (server.tf) and this service role, which
Amazon Bedrock assumes to read the submitted requests from S3 and write the results back.
*/

locals {
  # Create batch service role only if enabled and no user-provided role
  create_bedrock_batch_role = var.aws_bedrock_batch_role_create && var.aws_bedrock_batch_role_arn == null

  # Determine the batch service role to use for the application
  # Priority: user-specified role > auto-created role > null (Batch API disabled)
  bedrock_batch_role_arn = var.aws_bedrock_batch_role_arn != null ? var.aws_bedrock_batch_role_arn : (
    local.create_bedrock_batch_role ? aws_iam_role.batch[0].arn : null
  )

  # Batches prefix, using the application default when unset.
  s3_batches_prefix = var.aws_s3_batches_prefix != null ? var.aws_s3_batches_prefix : "batches/"

  # Every bucket a batch may use: the batch runs in the region that served it, on that region's
  # bucket, and falls back to the general purpose bucket.
  batch_buckets = distinct(compact(concat(
    [local.s3_bucket_name],
    values(local.regional_buckets_combined),
  )))

  # Keys encrypting the module-managed buckets above, which the service role must use to read the
  # requests and write the results.
  batch_buckets_kms_key_arns = concat(
    local.create_s3_bucket ? [module.kms_key.arn] : [],
    local.regional_buckets_kms_arns_combined,
  )
}

# Scoped to this account and to batch jobs: without both conditions, another account's jobs could
# assume this role.
data "aws_iam_policy_document" "batch_assume_role" {
  count = local.create_bedrock_batch_role ? 1 : 0
  statement {
    sid    = "BedrockBatchAssumeRole"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:model-invocation-job/*"]
    }
  }
}

resource "aws_iam_role" "batch" {
  count              = local.create_bedrock_batch_role ? 1 : 0
  name               = "${local.name}-batch"
  assume_role_policy = data.aws_iam_policy_document.batch_assume_role[0].json
  tags               = local.apn_tags
}

data "aws_iam_policy_document" "batch" {
  count = local.create_bedrock_batch_role ? 1 : 0

  dynamic "statement" {
    for_each = length(local.batch_buckets) > 0 ? [1] : []
    content {
      sid       = "BatchDataAccess"
      actions   = ["s3:GetObject", "s3:PutObject"]
      resources = [for bucket in local.batch_buckets : "arn:aws:s3:::${bucket}/${local.s3_batches_prefix}*"]
    }
  }

  dynamic "statement" {
    for_each = length(local.batch_buckets) > 0 ? [1] : []
    content {
      sid       = "BatchDataListing"
      actions   = ["s3:ListBucket"]
      resources = [for bucket in local.batch_buckets : "arn:aws:s3:::${bucket}"]
      condition {
        test     = "StringLike"
        variable = "s3:prefix"
        values   = ["${local.s3_batches_prefix}*"]
      }
    }
  }

  # A cross-region inference profile needs the permission on both the profile and the foundation
  # models behind it.
  statement {
    sid     = "BatchModelInvocation"
    actions = ["bedrock:InvokeModel"]
    resources = [
      "arn:aws:bedrock:*::foundation-model/*",
      "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*",
    ]
  }

  # The module-managed buckets are SSE-KMS encrypted, so reading and writing batch data through
  # them needs the key as well as the objects.
  dynamic "statement" {
    for_each = length(local.batch_buckets_kms_key_arns) > 0 ? [1] : []
    content {
      sid       = "BatchDataKms"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = local.batch_buckets_kms_key_arns
      condition {
        test     = "StringLike"
        variable = "kms:ViaService"
        values   = ["s3.*.amazonaws.com"]
      }
    }
  }
}

# Inline policy: it exists only for this role and cannot be attached to another principal.
resource "aws_iam_role_policy" "batch" {
  count  = local.create_bedrock_batch_role ? 1 : 0
  name   = "${local.name}-batch"
  role   = aws_iam_role.batch[0].id
  policy = data.aws_iam_policy_document.batch[0].json
}

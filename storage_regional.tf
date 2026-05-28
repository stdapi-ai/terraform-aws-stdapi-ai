/*
Regional S3 storage for Bedrock operations
*/

locals {
  regional_buckets_to_create = (
    var.aws_s3_regional_buckets_create && var.aws_bedrock_regions != null
    ? toset([
      for r in var.aws_bedrock_regions :
      r if r != data.aws_region.current.region
      && !contains(keys(coalesce(var.aws_s3_regional_buckets, {})), r)
    ])
    : toset([])
  )

  regional_buckets_combined = merge(
    coalesce(var.aws_s3_regional_buckets, {}),
    { for r, b in aws_s3_bucket.regional : r => b.id }
  )

  regional_buckets_kms_arns_combined = concat(
    coalesce(var.aws_s3_buckets_kms_keys_arns, []),
    [for k in module.regional_kms : k.arn]
  )

  regional_bucket_names = { for r in local.regional_buckets_to_create : r => "${local.name_prefix}-${r}" }
}

module "regional_kms" {
  source   = "JGoutin/kms-key/aws"
  version  = "~> 1.1"
  for_each = local.regional_buckets_to_create

  name_prefix = local.name
  region      = each.key
}

resource "aws_s3_bucket" "regional" {
  for_each      = local.regional_buckets_to_create
  region        = each.key
  bucket        = local.regional_bucket_names[each.key]
  force_destroy = !var.deletion_protection
  tags          = { Name = local.regional_bucket_names[each.key] }
}

resource "aws_s3_bucket_public_access_block" "regional" {
  for_each                = aws_s3_bucket.regional
  region                  = each.key
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "regional" {
  for_each = aws_s3_bucket.regional
  region   = each.key
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "regional" {
  for_each   = aws_s3_bucket.regional
  region     = each.key
  bucket     = each.value.id
  depends_on = [aws_s3_bucket_versioning.regional]

  rule {
    id     = "tmp-cleanup"
    status = "Enabled"
    filter { prefix = coalesce(var.aws_s3_tmp_prefix, "tmp/") }
    expiration { days = 1 }
    noncurrent_version_expiration { noncurrent_days = 1 }
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }

  rule {
    id     = "intelligent-tiering"
    status = "Enabled"
    filter {}
    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "regional" {
  for_each = aws_s3_bucket.regional
  region   = each.key
  bucket   = each.value.id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      kms_master_key_id = module.regional_kms[each.key].arn
      sse_algorithm     = "aws:kms"
    }
  }
}

data "aws_iam_policy_document" "regional_bucket_policy" {
  for_each = aws_s3_bucket.regional
  statement {
    sid    = "EnforceTLS"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [each.value.arn, "${each.value.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "regional" {
  for_each = aws_s3_bucket.regional
  region   = each.key
  bucket   = each.value.id
  policy   = data.aws_iam_policy_document.regional_bucket_policy[each.key].json
}
/*
S3 storage
*/

locals {
  # Create bucket only if enabled and no user-provided bucket
  create_s3_bucket = var.aws_s3_bucket_create && var.aws_s3_bucket == null

  # Determine the bucket name to use for the application
  # Priority: user-specified bucket > auto-created bucket > null (no bucket)
  s3_bucket_name = var.aws_s3_bucket != null ? var.aws_s3_bucket : (local.create_s3_bucket ? aws_s3_bucket.main[0].id : null)

  # S3 temporary prefix
  s3_tmp_prefix = var.aws_s3_tmp_prefix != null ? var.aws_s3_tmp_prefix : "tmp/"

  # S3 Files API prefix
  s3_files_prefix = var.aws_s3_files_prefix != null ? var.aws_s3_files_prefix : "files/"

  # Videos prefix, using the application default when unset.
  s3_videos_prefix = var.aws_s3_videos_prefix != null ? var.aws_s3_videos_prefix : "videos/"
}

# Data source for user-provided bucket ARN
data "aws_s3_bucket" "user_provided" {
  count  = var.aws_s3_bucket != null ? 1 : 0
  bucket = var.aws_s3_bucket
}

resource "aws_s3_bucket" "main" {
  count         = local.create_s3_bucket ? 1 : 0
  bucket        = local.name
  force_destroy = !var.deletion_protection
  tags          = merge(local.tags, { Name = local.name })
}

resource "aws_s3_bucket_public_access_block" "main" {
  count                   = local.create_s3_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.main[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "main" {
  count  = local.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.main[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count      = local.create_s3_bucket ? 1 : 0
  bucket     = aws_s3_bucket.main[0].id
  depends_on = [aws_s3_bucket_versioning.main]

  # Delete temporary files after 1 day (as recommended in docs)
  rule {
    id     = "tmp-cleanup"
    status = "Enabled"
    filter {
      prefix = local.s3_tmp_prefix
    }
    expiration {
      days = 1
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  # Expire Files API objects tagged stdapi-ai.expires=true (current tag key).
  rule {
    id     = "stdapi-files-expiration"
    status = "Enabled"
    filter {
      and {
        prefix = local.s3_files_prefix
        tags = {
          "stdapi-ai.expires" = "true"
        }
      }
    }
    expiration {
      days = 30
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  # Backward-compatibility rule for objects tagged with the old expires=true key.
  # Can be removed 30+ days after the stdapi-ai.expires rename is deployed.
  rule {
    id     = "stdapi-files-expiration-legacy"
    status = "Enabled"
    filter {
      and {
        prefix = local.s3_files_prefix
        tags = {
          expires = "true"
        }
      }
    }
    expiration {
      days = 30
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  # Expire generated videos to match AWS_S3_VIDEOS_EXPIRES_AFTER (whole days, rounded up)
  dynamic "rule" {
    for_each = var.aws_s3_videos_expires_after != null ? [1] : []
    content {
      id     = "stdapi-videos-expiration"
      status = "Enabled"
      filter {
        prefix = local.s3_videos_prefix
      }
      expiration {
        days = ceil(var.aws_s3_videos_expires_after / 86400)
      }
      noncurrent_version_expiration {
        noncurrent_days = 1
      }
    }
  }

  # Transition to Intelligent-Tiering for cost optimization
  rule {
    id     = "intelligent-tiering"
    status = "Enabled"
    filter {}
    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  count  = local.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.main[0].id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      kms_master_key_id = module.kms_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

data "aws_iam_policy_document" "main_bucket_policy" {
  count     = local.create_s3_bucket ? 1 : 0
  policy_id = local.name
  statement {
    sid    = "EnforceTLS"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.main[0].arn,
      "${aws_s3_bucket.main[0].arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "main" {
  count  = local.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.main[0].id
  policy = data.aws_iam_policy_document.main_bucket_policy[0].json
}

# Server access logging to the shared logs bucket (alb.tf). S3 access log destinations must be in
# the same Region as the source bucket, so this only covers the main bucket, not the regional ones.
resource "aws_s3_bucket_logging" "main" {
  count         = local.create_s3_bucket ? 1 : 0
  bucket        = aws_s3_bucket.main[0].id
  target_bucket = aws_s3_bucket.logs[0].id
  target_prefix = "s3-access-logs/main/"
}

# Zero-config EventBridge notifications — no targets/rules required for this to satisfy compliance.
resource "aws_s3_bucket_notification" "main" {
  count       = local.create_s3_bucket ? 1 : 0
  bucket      = aws_s3_bucket.main[0].id
  eventbridge = true
}

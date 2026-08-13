/*
S3 vector storage for the Vector Stores API

Deliberately single-region, unlike the regional buckets: those exist because an S3 URI handed
to a model must be co-located with it, and nothing ever hands a vector bucket to a model. The
server embeds through Bedrock and writes the vectors itself, so one bucket in one region is
enough — which is why the application setting is the singular AWS_S3_VECTORS_REGION.
*/

locals {
  # Create vector bucket only if enabled and no user-provided bucket
  create_s3_vectors_bucket = var.aws_s3_vectors_bucket_create && var.aws_s3_vectors_bucket == null

  # Region holding the vector bucket, defaulting to the region this module is deployed in.
  # Always resolved to a concrete region: the s3vectors IAM statements embed it in their ARNs.
  s3_vectors_region = var.aws_s3_vectors_region != null ? var.aws_s3_vectors_region : data.aws_region.current.region

  s3_vectors_bucket_created_name = "${local.name_prefix}-vectors-${local.s3_vectors_region}"

  # Determine the vector bucket name to use for the application
  # Priority: user-specified bucket > auto-created bucket > null (Vector Stores API disabled)
  s3_vectors_bucket_name = var.aws_s3_vectors_bucket != null ? var.aws_s3_vectors_bucket : (
    local.create_s3_vectors_bucket ? aws_s3vectors_vector_bucket.main[0].vector_bucket_name : null
  )

  # KMS key the task role uses through S3 Vectors, for the created bucket or a user-provided one
  s3_vectors_kms_key_arn = local.create_s3_vectors_bucket ? module.vectors_kms[0].arn : var.aws_s3_vectors_kms_key_arn

  # Regions where Amazon S3 Vectors is available, per
  # https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-vectors-regions-quotas.html
  s3_vectors_regions = [
    "af-south-1", "ap-east-1", "ap-east-2", "ap-northeast-1", "ap-northeast-2", "ap-northeast-3",
    "ap-south-1", "ap-south-2", "ap-southeast-1", "ap-southeast-2", "ap-southeast-3",
    "ap-southeast-4", "ap-southeast-5", "ap-southeast-6", "ap-southeast-7", "ca-central-1",
    "ca-west-1", "eu-central-1", "eu-central-2", "eu-north-1", "eu-south-1", "eu-south-2",
    "eu-west-1", "eu-west-2", "eu-west-3", "eusc-de-east-1", "mx-central-1", "sa-east-1",
    "us-east-1", "us-east-2", "us-gov-east-1", "us-gov-west-1", "us-west-1", "us-west-2",
  ]
}

# Dedicated KMS key: the vector bucket may live outside this module's region, and its key policy
# must name the S3 Vectors service principal, which the shared key has no reason to carry.
module "vectors_kms" {
  source  = "JGoutin/kms-key/aws"
  version = "~> 1.2"
  count   = local.create_s3_vectors_bucket ? 1 : 0

  name_prefix           = "${local.name_prefix}-vectors"
  region                = local.s3_vectors_region
  tags                  = local.apn_tags
  policy_documents_json = [data.aws_iam_policy_document.vectors_kms_policy[0].json]
}

# S3 Vectors maintains and optimizes the indexes in the background, under its own service
# principal, so the key policy must let that principal decrypt.
data "aws_iam_policy_document" "vectors_kms_policy" {
  count = local.create_s3_vectors_bucket ? 1 : 0
  statement {
    sid    = "AllowS3VectorsServicePrincipal"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["indexing.s3vectors.amazonaws.com"]
    }
    actions = ["kms:Decrypt"]
    # A key policy is scoped to its own key; "*" cannot widen it to any other key.
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:s3vectors:${local.s3_vectors_region}:${data.aws_caller_identity.current.account_id}:bucket/*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "kms:EncryptionContextKeys"
      values   = ["aws:s3vectors:arn", "aws:s3vectors:resource-id"]
    }
  }
}

# A vector bucket is a distinct resource type from a general purpose bucket: it is reachable only
# through the s3vectors HTTPS API, so it takes no public access block, versioning or lifecycle
# configuration, and needs no TLS-enforcing bucket policy.
resource "aws_s3vectors_vector_bucket" "main" {
  count              = local.create_s3_vectors_bucket ? 1 : 0
  region             = local.s3_vectors_region
  vector_bucket_name = local.s3_vectors_bucket_created_name
  force_destroy      = !var.deletion_protection
  tags               = merge(local.apn_tags, { Name = local.s3_vectors_bucket_created_name })

  encryption_configuration {
    sse_type    = "aws:kms"
    kms_key_arn = module.vectors_kms[0].arn
  }

  lifecycle {
    # var.aws_s3_vectors_region validates an explicit value; this covers the default, which is
    # the region the module is deployed in and cannot be checked by the variable itself.
    precondition {
      condition     = contains(local.s3_vectors_regions, local.s3_vectors_region)
      error_message = "Amazon S3 Vectors is not available in ${local.s3_vectors_region}. Set var.aws_s3_vectors_region to a supported region."
    }
  }
}

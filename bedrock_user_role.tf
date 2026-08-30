/*
Per-end-user cost attribution role

The server opens one role session per end user and signs that user's Amazon Bedrock model
invocations with it, so AWS reports the spend per end user. The role stays the operator's to
provide through aws_bedrock_user_role_arn; this file creates a fully managed one instead when
aws_bedrock_user_role_create is set.
*/

locals {
  # Create the per-end-user role only if enabled and no user-provided role
  create_bedrock_user_role = var.aws_bedrock_user_role_create && var.aws_bedrock_user_role_arn == null

  # Determine the per-end-user role to use for the application
  # Priority: user-specified role > auto-created role > null (cost attribution disabled)
  bedrock_user_role_arn = var.aws_bedrock_user_role_arn != null ? var.aws_bedrock_user_role_arn : (
    local.create_bedrock_user_role ? aws_iam_role.end_user[0].arn : null
  )

  # IAM caps a role name at 64 characters, and a long name_prefix reaches it. Both names below
  # truncate and hash exactly as the ECS module does, which is why its version constraint requires
  # the release that introduced that scheme: reconstructing a name only works while both agree.
  iam_role_name_limit = 64

  end_user_role_name_raw = "${local.name}-end-user"
  end_user_role_name = (
    length(local.end_user_role_name_raw) <= local.iam_role_name_limit ? local.end_user_role_name_raw :
    "${substr(local.end_user_role_name_raw, 0, 55)}-${substr(sha256(local.end_user_role_name_raw), 0, 8)}"
  )

  # The task role that opens the sessions. It is named after the ECS module's own convention rather
  # than read from it: the task role carries the policy that grants the session, so reading its ARN
  # would make the role granting the session depend on the role opening it. The check block below
  # is what tells an operator the reconstruction stopped matching.
  user_role_task_role_name_raw = "${local.name}-task-role"
  user_role_task_role_name = (
    length(local.user_role_task_role_name_raw) <= local.iam_role_name_limit ? local.user_role_task_role_name_raw :
    "${substr(local.user_role_task_role_name_raw, 0, 55)}-${substr(sha256(local.user_role_task_role_name_raw), 0, 8)}"
  )
  user_role_task_role_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${local.user_role_task_role_name}"
}

# A reconstructed name is only correct while the ECS module keeps naming its task role the same
# way, and nothing in a plan would otherwise notice it stopped: the apply stays clean, and every
# request carrying an end user identity fails AssumeRole at runtime instead. A check block reports
# that as a warning rather than an error, so a genuinely absent role -- the first apply, or a
# deployment scaled to nothing -- does not block the run.
check "end_user_role_trusts_the_task_role" {
  # A nested data block takes no count, so the lookup runs whether or not the role is created. It
  # resolves for every applied deployment: the ECS module creates this task role unconditionally.
  data "aws_iam_role" "task_role" {
    name       = local.user_role_task_role_name
    depends_on = [module.server]
  }

  assert {
    condition     = !local.create_bedrock_user_role || data.aws_iam_role.task_role.arn == local.user_role_task_role_arn
    error_message = "The per-end-user role trusts ${local.user_role_task_role_arn}, which is not the task role this deployment runs under. The ECS module's naming rule changed, so every request that identifies an end user would fail to assume the role."
  }
}

# The task role does not exist yet on the first apply, and IAM rejects a principal ARN that does
# not resolve. Naming the account and testing the ARN in a condition grants exactly the same single
# principal. Tagging the session is a separate action from assuming the role, and the server needs
# both to carry the end user identity into the session.
data "aws_iam_policy_document" "end_user_assume_role" {
  count = local.create_bedrock_user_role ? 1 : 0
  statement {
    sid    = "TaskRoleEndUserSessions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = ["sts:AssumeRole", "sts:TagSession"]
    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = [local.user_role_task_role_arn]
    }
  }
}

resource "aws_iam_role" "end_user" {
  count              = local.create_bedrock_user_role ? 1 : 0
  name               = local.end_user_role_name
  description        = "End user of the stdapi.ai gateway, one role session per end user"
  assume_role_policy = data.aws_iam_policy_document.end_user_assume_role[0].json
  tags               = local.apn_tags
}

data "aws_iam_policy_document" "end_user" {
  count = local.create_bedrock_user_role ? 1 : 0

  # Only four bedrock-runtime operations are ever signed as the end user (Converse, ConverseStream,
  # InvokeModel, InvokeModelWithResponseStream); every other call the server makes keeps the task
  # role's own identity, so nothing else belongs here. The resource is left open for the same
  # reason the server's own statement leaves it open: an invocation may name a foundation model, a
  # cross-region or application inference profile, a prompt router, a provisioned, custom or
  # imported model, or a Marketplace model endpoint, and naming a subset of those shapes would
  # deny the rest at runtime rather than bound anything the actions do not already bound.
  statement {
    sid = "EndUserModelInvoke"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      # A built-in tool runs inside the invocation the end user signed, so it is authorized against
      # this role rather than the server's.
      "bedrock:InvokeTool",
    ]
    resources = ["*"]
  }

  # A guardrail applied by the invocation is evaluated against the session that made it. Unscoped
  # for the same reason as the server's own statement: a request may name any guardrail.
  statement {
    sid       = "EndUserApplyGuardrail"
    actions   = ["bedrock:ApplyGuardrail"]
    resources = ["arn:${data.aws_partition.current.partition}:bedrock:*:*:guardrail/*"]
  }

  # A web search runs inside the invocation too. ExternalWebAccess follows the server's own grant:
  # without it every search is answered from the in-AWS index and cache.
  statement {
    sid = "EndUserWebSearch"
    actions = concat(
      [
        "bedrock-websearch:InvokeSearch",
        "bedrock-websearch:InvokeFetch",
      ],
      var.aws_bedrock_external_web_access == true ? ["bedrock-websearch:ExternalWebAccess"] : [],
    )
    resources = ["arn:${data.aws_partition.current.partition}:bedrock-websearch:*:*:*"]
  }

  # An invocation may reference its media by S3 URI instead of carrying the bytes, and Amazon
  # Bedrock reads that object with the session that signed the invocation. The three statements
  # below therefore repeat the object grants the task role holds, on the same buckets and behind
  # the same guards, read-only: the role never writes an object, because the upload the server
  # does before the invocation keeps the task role's own identity.
  dynamic "statement" {
    for_each = local.s3_bucket_name != null ? [1] : []
    content {
      sid     = "EndUserS3FileStorage"
      actions = ["s3:GetObject"]
      resources = [
        var.aws_s3_bucket != null ? "arn:aws:s3:::${var.aws_s3_bucket}/*" : "${aws_s3_bucket.main[0].arn}/*"
      ]
    }
  }

  dynamic "statement" {
    for_each = var.aws_s3_accepted_buckets != null ? [1] : []
    content {
      sid     = "EndUserS3AcceptedBuckets"
      actions = ["s3:GetObject"]
      resources = [
        for bucket in keys(var.aws_s3_accepted_buckets) : "arn:aws:s3:::${bucket}/*"
      ]
    }
  }

  dynamic "statement" {
    for_each = length(local.regional_buckets_combined) > 0 ? [1] : []
    content {
      sid     = "EndUserS3RegionalBuckets"
      actions = ["s3:GetObject"]
      resources = [
        for bucket in values(local.regional_buckets_combined) : "arn:aws:s3:::${bucket}/*"
      ]
    }
  }

  # Reading an encrypted object needs the key it was written with, so each of the three grants
  # above carries the matching decrypt, conditioned on the call arriving through Amazon S3: the
  # role can never use these keys for anything else.
  dynamic "statement" {
    for_each = local.create_s3_bucket ? [1] : []
    content {
      sid       = "EndUserKMSEncryptedBucket"
      actions   = ["kms:Decrypt"]
      resources = [module.kms_key.arn]
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["s3.${data.aws_region.current.region}.amazonaws.com"]
      }
    }
  }

  dynamic "statement" {
    for_each = var.aws_s3_accepted_buckets_kms_key_arn != null ? [1] : []
    content {
      sid       = "EndUserKMSAcceptedBuckets"
      actions   = ["kms:Decrypt"]
      resources = var.aws_s3_accepted_buckets_kms_key_arn
      condition {
        test     = "StringLike"
        variable = "kms:ViaService"
        values   = ["s3.*.amazonaws.com"]
      }
    }
  }

  dynamic "statement" {
    for_each = length(local.regional_buckets_kms_arns_combined) > 0 ? [1] : []
    content {
      sid       = "EndUserKMSRegionalBuckets"
      actions   = ["kms:Decrypt"]
      resources = local.regional_buckets_kms_arns_combined
      condition {
        test     = "StringLike"
        variable = "kms:ViaService"
        values   = ["s3.*.amazonaws.com"]
      }
    }
  }

  # Amazon Bedrock forwards a Marketplace model endpoint invocation to SageMaker under the end
  # user's session, so the role needs it as well. Conditioned on the call arriving through Amazon
  # Bedrock, so the role can never reach an endpoint directly.
  dynamic "statement" {
    for_each = var.aws_bedrock_marketplace_endpoints_enabled == true ? [1] : []
    content {
      sid = "EndUserMarketplaceEndpointInvoke"
      actions = [
        "sagemaker:InvokeEndpoint",
        "sagemaker:InvokeEndpointWithResponseStream",
      ]
      resources = ["arn:${data.aws_partition.current.partition}:sagemaker:*:${data.aws_caller_identity.current.account_id}:endpoint/*"]
      condition {
        test     = "StringEquals"
        variable = "aws:CalledViaLast"
        values   = ["bedrock.amazonaws.com"]
      }
    }
  }
}

# Fails the plan on the combination the server refuses at startup: a validation surface, holding no
# infrastructure.
resource "terraform_data" "bedrock_user_role_validation" {
  count = var.aws_bedrock_user_role_require_identity == true ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.bedrock_user_role_arn != null
      error_message = "aws_bedrock_user_role_require_identity requires a per-end-user role: set aws_bedrock_user_role_create or aws_bedrock_user_role_arn. Without one there is no session to attribute a request to, so requiring an identity would reject every request the server serves."
    }
  }
}

# Inline policy: it exists only for this role and cannot be attached to another principal.
resource "aws_iam_role_policy" "end_user" {
  count  = local.create_bedrock_user_role ? 1 : 0
  name   = local.end_user_role_name
  role   = aws_iam_role.end_user[0].id
  policy = data.aws_iam_policy_document.end_user[0].json
}

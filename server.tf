/*
Server on ECS
*/

module "server" {
  source                            = "JGoutin/ecs-fargate/aws"
  version                           = "~> 1.3"
  tags                              = local.apn_tags
  kms_key_id                        = module.kms_key.id
  kms_policy_dependency             = module.kms_key.policy_dependency
  subnets_ids                       = module.vpc.subnets_ids
  cloudwatch_logs_retention_in_days = var.cloudwatch_logs_retention_in_days
  container_insight                 = var.container_insight
  name_prefix                       = local.name_prefix
  security_group_ids                = compact([module.vpc.security_group_id])
  task_role_policies                = concat([aws_iam_policy.server.arn], var.ecs_task_role_policy_arns)
  cpu_architecture                  = var.cpu_architecture
  cpu                               = var.cpu
  memory                            = var.memory
  assign_public_ip                  = local.internet_access_required && !var.nat_gateways_allowed
  deletion_protection               = var.deletion_protection

  # Service Discovery
  service_discovery_dns_namespace_id = var.service_discovery_dns_namespace_id
  service_discovery_dns_name         = var.service_discovery_dns_name

  # Auto-Scaling
  autoscaling_min_capacity                   = var.autoscaling_min_capacity
  autoscaling_max_capacity                   = var.autoscaling_max_capacity
  autoscaling_cpu_target_percent             = var.autoscaling_cpu_target_percent
  autoscaling_memory_target_percent          = var.autoscaling_memory_target_percent
  autoscaling_alb_target_requests_per_target = var.autoscaling_alb_target_requests_per_target
  autoscaling_alb_resource_label             = var.alb_enabled && var.autoscaling_alb_target_requests_per_target != null ? "${aws_lb.main[0].arn_suffix}/${aws_lb_target_group.main[0].arn_suffix}" : null
  autoscaling_scale_in_cooldown              = var.autoscaling_scale_in_cooldown
  autoscaling_scale_out_cooldown             = var.autoscaling_scale_out_cooldown
  autoscaling_schedule_stop                  = var.autoscaling_schedule_stop
  autoscaling_schedule_start                 = var.autoscaling_schedule_start
  autoscaling_spot_percent                   = var.autoscaling_spot_percent
  autoscaling_spot_on_demand_min_capacity    = var.autoscaling_spot_on_demand_min_capacity

  # Monitoring
  alarms_enabled = var.alarms_enabled
  sns_topic_arn  = var.sns_topic_arn

  container_definitions = {
    main = {
      image = local.container_image
      environment = merge(
        { for k, v in {
          AWS_S3_BUCKET                          = local.s3_bucket_name
          AWS_POLLY_REGION                       = var.aws_polly_region
          AWS_COMPREHEND_REGION                  = var.aws_comprehend_region
          AWS_BEDROCK_REGIONS                    = var.aws_bedrock_regions != null ? join(",", var.aws_bedrock_regions) : null
          AWS_BEDROCK_MANTLE_REGIONS             = var.aws_bedrock_mantle_regions != null ? join(",", var.aws_bedrock_mantle_regions) : null
          AWS_BEDROCK_MANTLE_PREFERRED_MODELS    = var.aws_bedrock_mantle_preferred_models != null ? join(",", var.aws_bedrock_mantle_preferred_models) : null
          AWS_BEDROCK_MANTLE_PROJECT             = var.aws_bedrock_mantle_project
          AWS_BEDROCK_GUARDRAIL_IDENTIFIER       = var.aws_bedrock_guardrail_identifier
          AWS_BEDROCK_GUARDRAIL_VERSION          = var.aws_bedrock_guardrail_version
          AWS_BEDROCK_GUARDRAIL_TRACE            = var.aws_bedrock_guardrail_trace
          AWS_BEDROCK_SESSION_ENCRYPTION_KEY_ARN = var.aws_bedrock_session_encryption_key_arn
          AWS_TRANSCRIBE_REGION                  = var.aws_transcribe_region
          AWS_TRANSCRIBE_S3_BUCKET               = var.aws_transcribe_s3_bucket
          AWS_S3_TMP_PREFIX                      = var.aws_s3_tmp_prefix
          AWS_S3_FILES_PREFIX                    = var.aws_s3_files_prefix
          AWS_S3_VIDEOS_PREFIX                   = var.aws_s3_videos_prefix
          AWS_TRANSLATE_REGION                   = var.aws_translate_region
          TIMEZONE                               = var.timezone
          OPENAI_ROUTES_PREFIX                   = var.openai_routes_prefix
          ANTHROPIC_ROUTES_PREFIX                = var.anthropic_routes_prefix
          COHERE_ROUTES_PREFIX                   = var.cohere_routes_prefix
          API_KEY_SSM_PARAMETER                  = var.api_key_ssm_parameter
          API_KEY_SECRETSMANAGER_SECRET          = var.api_key_secretsmanager_secret
          API_KEY_SECRETSMANAGER_KEY             = var.api_key_secretsmanager_key
          OTEL_SERVICE_NAME                      = var.otel_service_name
          OTEL_EXPORTER_ENDPOINT                 = var.otel_exporter_endpoint
          LOG_LEVEL                              = var.log_level
          DEFAULT_MODEL_PARAMS                   = var.default_model_params
          DEFAULT_MODEL_SERVICE_TIERS            = var.default_model_service_tiers
          DEFAULT_TTS_MODEL                      = var.default_tts_model
          DEFAULT_TTS_LANGUAGE                   = var.default_tts_language
          TOKENS_ESTIMATION_DEFAULT_ENCODING     = var.tokens_estimation_default_encoding
          CLOUDWATCH_METRICS_NAMESPACE           = var.cloudwatch_metrics_namespace
          ANTHROPIC_BETA_ALLOWLIST               = var.anthropic_beta_allowlist
          MCP_INCLUDE_TOOLS                      = var.mcp_include_tools
          MCP_EXCLUDE_TOOLS                      = var.mcp_exclude_tools
          AWS_BEDROCK_REGION_ROUTING             = var.aws_bedrock_region_routing
          IMAGE_GENERATION_MODEL                 = var.image_generation_model
        } : k => v if v != null },
        { for k, v in {
          ENABLE_MCP_STREAMABLE_HTTP                             = var.enable_mcp_streamable_http
          ENABLE_MCP_SSE                                         = var.enable_mcp_sse
          AWS_S3_ACCELERATE                                      = var.aws_s3_accelerate
          AWS_BEDROCK_CROSS_REGION_INFERENCE                     = var.aws_bedrock_cross_region_inference
          AWS_BEDROCK_CROSS_REGION_INFERENCE_GLOBAL              = var.aws_bedrock_cross_region_inference_global
          AWS_BEDROCK_LEGACY                                     = var.aws_bedrock_legacy
          AWS_BEDROCK_MARKETPLACE_AUTO_SUBSCRIBE                 = var.aws_bedrock_marketplace_auto_subscribe
          AWS_BEDROCK_ALLOW_CROSS_REGION_INFERENCE_PROFILE_ARN   = var.aws_bedrock_allow_cross_region_inference_profile_arn
          AWS_BEDROCK_ALLOW_APPLICATION_INFERENCE_PROFILE_ARN    = var.aws_bedrock_allow_application_inference_profile_arn
          AWS_BEDROCK_ALLOW_PROMPT_ROUTER_ARN                    = var.aws_bedrock_allow_prompt_router_arn
          OTEL_ENABLED                                           = var.otel_enabled
          OTEL_SAMPLE_RATE                                       = var.otel_sample_rate
          LOG_REQUEST_PARAMS                                     = var.log_request_params
          LOG_CLIENT_IP                                          = var.log_client_ip
          STRICT_INPUT_VALIDATION                                = var.strict_input_validation
          TOKENS_ESTIMATION                                      = var.tokens_estimation
          ENABLE_DOCS                                            = var.enable_docs
          ENABLE_REDOC                                           = var.enable_redoc
          ENABLE_OPENAPI_JSON                                    = var.enable_openapi_json
          ENABLE_PROXY_HEADERS                                   = (var.enable_proxy_headers != null || (var.alb_enabled && var.log_client_ip == true)) ? true : null
          ENABLE_GZIP                                            = var.enable_gzip
          SSRF_PROTECTION_BLOCK_PRIVATE_NETWORKS                 = var.ssrf_protection_block_private_networks
          MODEL_CACHE_SECONDS                                    = var.model_cache_seconds
          DROP_UNSUPPORTED_SYSTEM_PROMPT                         = var.drop_unsupported_system_prompt
          AWS_BEDROCK_ALLOW_GUARDRAIL_OVERRIDE                   = var.aws_bedrock_allow_guardrail_override
          ANTHROPIC_BETA_FILTER                                  = var.anthropic_beta_filter
          AWS_ADAPTIVE_RETRY                                     = var.aws_adaptive_retry
          AWS_MAX_POOL_CONNECTIONS                               = var.aws_max_pool_connections
          AWS_CONNECT_TIMEOUT                                    = var.aws_connect_timeout
          AWS_BEDROCK_REGION_ROUTING_QUOTA_BACKOFF_SECONDS       = var.aws_bedrock_region_routing_quota_backoff_seconds
          AWS_BEDROCK_REGION_ROUTING_UNAVAILABLE_BACKOFF_SECONDS = var.aws_bedrock_region_routing_unavailable_backoff_seconds
          AWS_BEDROCK_REGION_ROUTING_MAX_QUOTA_BACKOFF_SECONDS   = var.aws_bedrock_region_routing_max_quota_backoff_seconds
          AWS_BEDROCK_REGION_ROUTING_QUOTA_STALE_FACTOR          = var.aws_bedrock_region_routing_quota_stale_factor
          AWS_BEDROCK_MAX_RETRIES                                = var.aws_bedrock_max_retries
          AWS_FAILOVER_MAX_RETRIES                               = var.aws_failover_max_retries
          AI_RESPONSE_TIMEOUT                                    = var.ai_response_timeout
          AWS_BEDROCK_DEPRECATED_MODEL_FALLBACK                  = var.aws_bedrock_deprecated_model_fallback
          AWS_S3_VIDEOS_EXPIRES_AFTER                            = var.aws_s3_videos_expires_after
          CLOUDWATCH_METRICS                                     = var.cloudwatch_metrics
          COST_TRACKING                                          = var.cost_tracking
          AWS_BEDROCK_MANTLE_ENABLED                             = var.aws_bedrock_mantle_enabled
          AWS_BEDROCK_MANTLE_SERVICE_HEADER                      = var.aws_bedrock_mantle_service_header
          AWS_BEDROCK_ALLOW_MANTLE_PROJECT_OVERRIDE              = var.aws_bedrock_allow_mantle_project_override
          MAX_INPUT_FILE_SIZE                                    = var.max_input_file_size
          MAX_CONCURRENT_INPUT_DOWNLOADS                         = var.max_concurrent_input_downloads
        } : k => tostring(v) if v != null },
        { for k, v in {
          AWS_S3_REGIONAL_BUCKETS           = local.regional_buckets_combined
          AWS_BEDROCK_MODEL_ARN_MAPPING     = var.aws_bedrock_model_arn_mapping
          CORS_ALLOW_ORIGINS                = var.cors_allow_origins
          TRUSTED_HOSTS                     = var.trusted_hosts
          MODEL_ALIASES                     = var.model_aliases
          AWS_S3_ACCEPTED_BUCKETS           = var.aws_s3_accepted_buckets
          AWS_BEDROCK_MODEL_REGION_RESTRICT = var.aws_bedrock_model_region_restrict
          AWS_BEDROCK_DEPRECATED_MODELS     = var.aws_bedrock_deprecated_models
          COST_PRICE_OVERRIDES              = var.cost_price_overrides
          PROXY_TRUSTED_HOSTS               = var.proxy_trusted_hosts != null ? var.proxy_trusted_hosts : ((var.alb_enabled && var.log_client_ip == true) ? local.alb_subnets_cidr_blocks : null)
        } : k => jsonencode(v) if v != null }
      )
      secrets = var.api_key != null || var.api_key_create ? {
        API_KEY = var.api_key != null ? var.api_key : random_password.api_key[0].result
      } : null
      port_mappings = {
        http = {
          container_port    = local.port
          target_group_arns = var.alb_enabled ? [aws_lb_target_group.main[0].arn] : null
        }
      }
      health_check = {
        command      = ["CMD", "python3", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:${local.port}/health', timeout=5)"]
        interval     = 30
        timeout      = 5
        retries      = 3
        start_period = 30
      }
      read_only_root_filesystem = true
      # Matches the Chainguard python base image's default non-root user (nonroot, uid/gid 65532),
      # declared explicitly since Security Hub ECS.20 checks the task definition, not the image.
      user = "65532:65532"
      linux_parameters = {
        capabilities = { drop = ["ALL"] }
      }
      mount_points = {
        temp = { container_path = "/tmp" }
      }
    }
  }
}


resource "aws_iam_policy" "server" {
  name   = "${local.name}-policy"
  policy = data.aws_iam_policy_document.server.json
  tags   = local.apn_tags
}

data "aws_iam_policy_document" "server" {

  # Product usage (Always Required)
  statement {
    sid = "MarketplaceRegister"
    actions = [
      "aws-marketplace:RegisterUsage",
    ]
    resources = ["*"]
  }

  # Bedrock - Model & Tool Invocation (Always Required)
  statement {
    sid = "BedrockModelInvoke"
    actions = [
      "bedrock:CountTokens",
      "bedrock:GetAsyncInvoke",
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:InvokeTool",
      "bedrock:ListAsyncInvokes",
      "bedrock:Rerank",
    ]
    resources = ["*"]
  }

  # Bedrock - Async Invoke Tagging (Always Required)
  statement {
    sid = "BedrockAsyncInvokeTagging"
    actions = [
      "bedrock:ListTagsForResource",
      "bedrock:TagResource",
    ]
    resources = ["arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:async-invoke/*"]
  }

  # Bedrock - Session Storage for stored responses & chat completions (Always Required)
  statement {
    sid = "BedrockSessionStorage"
    actions = [
      "bedrock:CreateSession",
      "bedrock:CreateInvocation",
      "bedrock:PutInvocationStep",
      "bedrock:ListInvocations",
      "bedrock:ListInvocationSteps",
      "bedrock:GetInvocationStep",
      "bedrock:GetSession",
      "bedrock:EndSession",
      "bedrock:DeleteSession",
      "bedrock:TagResource",
      "bedrock:ListTagsForResource",
    ]
    resources = ["arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:session/*"]
  }

  # Bedrock - Session Listing for stored responses & chat completions (Always Required)
  statement {
    sid       = "BedrockSessionListing"
    actions   = ["bedrock:ListSessions"]
    resources = ["*"]
  }

  # Bedrock Mantle - Model Serving (Always Required; enabled by default, see aws_bedrock_mantle_enabled)
  statement {
    sid = "BedrockMantleInference"
    actions = [
      "bedrock-mantle:CreateInference",
      "bedrock-mantle:GetInference",
      "bedrock-mantle:DeleteInference",
      "bedrock-mantle:ListModels",
      "bedrock-mantle:GetModel",
      "bedrock-mantle:CancelInference",
    ]
    resources = ["arn:aws:bedrock-mantle:*:${data.aws_caller_identity.current.account_id}:project/*"]
  }

  # Bedrock Mantle - Bearer Token Authentication (Always Required)
  statement {
    sid       = "BedrockMantleBearerToken"
    actions   = ["bedrock-mantle:CallWithBearerToken"]
    resources = ["*"]
  }

  # Bedrock - Session Storage KMS encryption (Optional)
  dynamic "statement" {
    for_each = var.aws_bedrock_session_encryption_key_arn != null ? [1] : []
    content {
      sid = "BedrockSessionStorageKms"
      actions = [
        "kms:CreateGrant",
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKey",
      ]
      resources = [var.aws_bedrock_session_encryption_key_arn]
    }
  }

  # Pricing - Cost Tracking (Optional)
  dynamic "statement" {
    for_each = var.cost_tracking == true ? [1] : []
    content {
      sid       = "PricingCostTracking"
      actions   = ["pricing:GetProducts"]
      resources = ["*"]
    }
  }

  # Bedrock - Inference Profiles & Prompt Routers (Optional)
  dynamic "statement" {
    for_each = var.aws_bedrock_allow_cross_region_inference_profile_arn != false || var.aws_bedrock_allow_application_inference_profile_arn != false || var.aws_bedrock_allow_prompt_router_arn != false || length(var.aws_bedrock_model_arn_mapping) > 0 ? [1] : []
    content {
      sid = "BedrockInferenceProfiles"
      actions = [
        "bedrock:GetInferenceProfile",
        "bedrock:GetPromptRouter",
      ]
      resources = ["*"]
    }
  }

  # Bedrock - Model Discovery (Always Required)
  statement {
    sid = "BedrockModelDiscovery"
    actions = [
      "bedrock:ListFoundationModels",
      "bedrock:GetFoundationModelAvailability",
      "bedrock:ListProvisionedModelThroughputs",
      "bedrock:ListInferenceProfiles"
    ]
    resources = ["*"]
  }

  # Bedrock - Marketplace Auto-Subscribe (Optional)
  dynamic "statement" {
    for_each = var.aws_bedrock_marketplace_auto_subscribe != false ? [1] : []
    content {
      sid = "BedrockMarketplaceAutoSubscribe"
      actions = [
        "aws-marketplace:Subscribe",
        "aws-marketplace:ViewSubscriptions"
      ]
      resources = ["*"]
    }
  }

  # Bedrock - Guardrails (Always Required)
  # Needed beyond var.aws_bedrock_guardrail_identifier: the Moderations API
  # applies any guardrail named in the request, with no server-side setting.
  statement {
    sid       = "BedrockGuardrails"
    actions   = ["bedrock:ApplyGuardrail"]
    resources = ["arn:aws:bedrock:*:*:guardrail/*"]
  }

  # Bedrock - Guardrail checks (Always Required)
  # Backs the default Moderations model. The operation runs standalone checks
  # and takes no guardrail identifier, so it has no resource to scope to.
  statement {
    sid       = "BedrockGuardrailChecks"
    actions   = ["bedrock:InvokeGuardrailChecks"]
    resources = ["*"]
  }

  # S3 - File Storage (Optional)
  dynamic "statement" {
    for_each = local.s3_bucket_name != null ? [1] : []
    content {
      sid = "S3FileStorage"
      actions = [
        "s3:PutObject",
        "s3:PutObjectTagging",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts",
      ]
      resources = [
        var.aws_s3_bucket != null ? "arn:aws:s3:::${var.aws_s3_bucket}/*" : "${aws_s3_bucket.main[0].arn}/*"
      ]
    }
  }

  # S3 - File Storage List (Optional, required for Files API list and multipart upload endpoints)
  dynamic "statement" {
    for_each = local.s3_bucket_name != null ? [1] : []
    content {
      sid     = "S3FileStorageList"
      actions = ["s3:ListBucket", "s3:ListBucketMultipartUploads"]
      resources = [
        var.aws_s3_bucket != null ? "arn:aws:s3:::${var.aws_s3_bucket}" : aws_s3_bucket.main[0].arn
      ]
    }
  }

  # S3 - Accepted Buckets for Input Data (Optional)
  dynamic "statement" {
    for_each = var.aws_s3_accepted_buckets != null ? [1] : []
    content {
      sid     = "S3AcceptedBuckets"
      actions = ["s3:GetObject"]
      resources = [
        for bucket in keys(var.aws_s3_accepted_buckets) : "arn:aws:s3:::${bucket}/*"
      ]
    }
  }

  # S3 - Regional Buckets for Bedrock (Optional)
  dynamic "statement" {
    for_each = length(local.regional_buckets_combined) > 0 ? [1] : []
    content {
      sid = "S3RegionalBuckets"
      actions = [
        "s3:PutObject",
        "s3:PutObjectTagging",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts",
      ]
      resources = [
        for bucket in values(local.regional_buckets_combined) : "arn:aws:s3:::${bucket}/*"
      ]
    }
  }

  # S3 - Regional Buckets List (Optional)
  dynamic "statement" {
    for_each = length(local.regional_buckets_combined) > 0 ? [1] : []
    content {
      sid     = "S3RegionalBucketsList"
      actions = ["s3:ListBucket", "s3:ListBucketMultipartUploads"]
      resources = [
        for bucket in values(local.regional_buckets_combined) : "arn:aws:s3:::${bucket}"
      ]
    }
  }

  # KMS - S3 Bucket Encryption (Optional, only for Terraform-managed bucket)
  dynamic "statement" {
    for_each = local.create_s3_bucket ? [1] : []
    content {
      sid = "KMSEncryptedBucket"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = [module.kms_key.arn]
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["s3.${data.aws_region.current.region}.amazonaws.com"]
      }
    }
  }

  # KMS - Regional S3 Buckets Encryption (Optional)
  dynamic "statement" {
    for_each = length(local.regional_buckets_kms_arns_combined) > 0 ? [1] : []
    content {
      sid = "KMSRegionalBuckets"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = local.regional_buckets_kms_arns_combined
      condition {
        test     = "StringLike"
        variable = "kms:ViaService"
        values   = ["s3.*.amazonaws.com"]
      }
    }
  }

  # KMS - Accepted S3 Buckets Encryption (Optional)
  dynamic "statement" {
    for_each = var.aws_s3_accepted_buckets_kms_key_arn != null ? [1] : []
    content {
      sid       = "KMSAcceptedBuckets"
      actions   = ["kms:Decrypt"]
      resources = var.aws_s3_accepted_buckets_kms_key_arn
      condition {
        test     = "StringLike"
        variable = "kms:ViaService"
        values   = ["s3.*.amazonaws.com"]
      }
    }
  }

  # Polly - Text-to-Speech (Always Enabled)
  statement {
    sid = "PollyTextToSpeech"
    actions = [
      "polly:SynthesizeSpeech",
      "polly:DescribeVoices"
    ]
    resources = ["*"]
  }

  # Transcribe - Speech-to-Text (Only if S3 bucket available)
  dynamic "statement" {
    for_each = local.s3_bucket_name != null || var.aws_transcribe_s3_bucket != null ? [1] : []
    content {
      sid = "TranscribeSpeechToText"
      actions = [
        "transcribe:StartTranscriptionJob",
        "transcribe:GetTranscriptionJob",
        "transcribe:DeleteTranscriptionJob"
      ]
      resources = ["*"]
    }
  }

  # Transcribe - Job Tagging (Only if S3 bucket available)
  dynamic "statement" {
    for_each = local.s3_bucket_name != null || var.aws_transcribe_s3_bucket != null ? [1] : []
    content {
      sid       = "TranscribeTagging"
      actions   = ["transcribe:TagResource"]
      resources = ["arn:aws:transcribe:*:${data.aws_caller_identity.current.account_id}:transcription-job/*"]
    }
  }

  # S3 - Transcribe Storage (Only if transcribe S3 bucket is different from main bucket)
  dynamic "statement" {
    for_each = var.aws_transcribe_s3_bucket != null && var.aws_transcribe_s3_bucket != local.s3_bucket_name ? [1] : []
    content {
      sid = "TranscribeS3Storage"
      actions = [
        "s3:PutObject",
        "s3:PutObjectTagging",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts",
      ]
      resources = ["arn:aws:s3:::${var.aws_transcribe_s3_bucket}/*"]
    }
  }

  # Comprehend - Language Detection & Content Moderation (Always Enabled)
  statement {
    sid = "Comprehend"
    actions = [
      "comprehend:DetectDominantLanguage",
      "comprehend:DetectToxicContent",
    ]
    resources = ["*"]
  }

  # Translate - Text Translation (Always Enabled)
  statement {
    sid       = "TranslateTextTranslation"
    actions   = ["translate:TranslateText"]
    resources = ["*"]
  }
}

/*
Server on ECS
*/

module "server" {
  source                            = "JGoutin/ecs-fargate/aws"
  version                           = "~> 1.1"
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
          AWS_S3_BUCKET                      = local.s3_bucket_name
          AWS_POLLY_REGION                   = var.aws_polly_region
          AWS_COMPREHEND_REGION              = var.aws_comprehend_region
          AWS_BEDROCK_REGIONS                = var.aws_bedrock_regions != null ? join(",", var.aws_bedrock_regions) : null
          AWS_BEDROCK_GUARDRAIL_IDENTIFIER   = var.aws_bedrock_guardrail_identifier
          AWS_BEDROCK_GUARDRAIL_VERSION      = var.aws_bedrock_guardrail_version
          AWS_BEDROCK_GUARDRAIL_TRACE        = var.aws_bedrock_guardrail_trace
          AWS_TRANSCRIBE_REGION              = var.aws_transcribe_region
          AWS_TRANSCRIBE_S3_BUCKET           = var.aws_transcribe_s3_bucket
          AWS_S3_TMP_PREFIX                  = var.aws_s3_tmp_prefix
          AWS_TRANSLATE_REGION               = var.aws_translate_region
          TIMEZONE                           = var.timezone
          OPENAI_ROUTES_PREFIX               = var.openai_routes_prefix
          API_KEY_SSM_PARAMETER              = var.api_key_ssm_parameter
          API_KEY_SECRETSMANAGER_SECRET      = var.api_key_secretsmanager_secret
          API_KEY_SECRETSMANAGER_KEY         = var.api_key_secretsmanager_key
          OTEL_SERVICE_NAME                  = var.otel_service_name
          OTEL_EXPORTER_ENDPOINT             = var.otel_exporter_endpoint
          LOG_LEVEL                          = var.log_level
          DEFAULT_MODEL_PARAMS               = var.default_model_params
          DEFAULT_TTS_MODEL                  = var.default_tts_model
          TOKENS_ESTIMATION_DEFAULT_ENCODING = var.tokens_estimation_default_encoding
        } : k => v if v != null },
        { for k, v in {
          AWS_S3_ACCELERATE                                    = var.aws_s3_accelerate
          AWS_BEDROCK_CROSS_REGION_INFERENCE                   = var.aws_bedrock_cross_region_inference
          AWS_BEDROCK_CROSS_REGION_INFERENCE_GLOBAL            = var.aws_bedrock_cross_region_inference_global
          AWS_BEDROCK_LEGACY                                   = var.aws_bedrock_legacy
          AWS_BEDROCK_MARKETPLACE_AUTO_SUBSCRIBE               = var.aws_bedrock_marketplace_auto_subscribe
          AWS_BEDROCK_ALLOW_CROSS_REGION_INFERENCE_PROFILE_ARN = var.aws_bedrock_allow_cross_region_inference_profile_arn
          AWS_BEDROCK_ALLOW_APPLICATION_INFERENCE_PROFILE_ARN  = var.aws_bedrock_allow_application_inference_profile_arn
          AWS_BEDROCK_ALLOW_PROMPT_ROUTER_ARN                  = var.aws_bedrock_allow_prompt_router_arn
          OTEL_ENABLED                                         = var.otel_enabled
          OTEL_SAMPLE_RATE                                     = var.otel_sample_rate
          LOG_REQUEST_PARAMS                                   = var.log_request_params
          LOG_CLIENT_IP                                        = var.log_client_ip
          STRICT_INPUT_VALIDATION                              = var.strict_input_validation
          TOKENS_ESTIMATION                                    = var.tokens_estimation
          ENABLE_DOCS                                          = var.enable_docs
          ENABLE_REDOC                                         = var.enable_redoc
          ENABLE_OPENAPI_JSON                                  = var.enable_openapi_json
          ENABLE_PROXY_HEADERS                                 = (var.enable_proxy_headers != null || (var.alb_enabled && var.log_client_ip == true)) ? true : null
          ENABLE_GZIP                                          = var.enable_gzip
          SSRF_PROTECTION_BLOCK_PRIVATE_NETWORKS               = var.ssrf_protection_block_private_networks
          MODEL_CACHE_SECONDS                                  = var.model_cache_seconds
        } : k => tostring(v) if v != null },
        { for k, v in {
          AWS_S3_REGIONAL_BUCKETS       = var.aws_s3_regional_buckets
          AWS_BEDROCK_MODEL_ARN_MAPPING = var.aws_bedrock_model_arn_mapping
          CORS_ALLOW_ORIGINS            = var.cors_allow_origins
          TRUSTED_HOSTS                 = var.trusted_hosts
        } : k => jsonencode(v) if v != null && (k != "AWS_BEDROCK_MODEL_ARN_MAPPING" || length(v) > 0) }
      )
      secrets = var.api_key != null || var.api_key_create ? {
        API_KEY = var.api_key != null ? var.api_key : random_password.api_key[0].result
      } : null
      port_mappings = var.alb_enabled ? {
        http = {
          container_port    = local.port
          target_group_arns = [aws_lb_target_group.main[0].arn]
        }
      } : null
      health_check = {
        command      = ["CMD", "python3", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:${local.port}/health', timeout=5)"]
        interval     = 30
        timeout      = 5
        retries      = 3
        start_period = 30
      }
      read_only_root_filesystem = true
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

  # Bedrock - Model Invocation (Always Required)
  statement {
    sid = "BedrockModelInvoke"
    actions = [
      "bedrock:GetAsyncInvoke",
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = ["*"]
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

  # Bedrock - Guardrails (Optional)
  dynamic "statement" {
    for_each = var.aws_bedrock_guardrail_identifier != null ? [1] : []
    content {
      sid       = "BedrockGuardrails"
      actions   = ["bedrock:ApplyGuardrail"]
      resources = ["arn:aws:bedrock:*:*:guardrail/*"]
    }
  }

  # S3 - File Storage (Optional)
  dynamic "statement" {
    for_each = local.s3_bucket_name != null ? [1] : []
    content {
      sid = "S3FileStorage"
      actions = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ]
      resources = [
        var.aws_s3_bucket != null ? "arn:aws:s3:::${var.aws_s3_bucket}/*" : "${aws_s3_bucket.main[0].arn}/*"
      ]
    }
  }

  # S3 - Regional Buckets for Bedrock (Optional)
  dynamic "statement" {
    for_each = var.aws_s3_regional_buckets != null ? [1] : []
    content {
      sid = "S3RegionalBuckets"
      actions = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ]
      resources = [
        for bucket in values(var.aws_s3_regional_buckets) : "arn:aws:s3:::${bucket}/*"
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
        values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
      }
    }
  }

  # KMS - Regional S3 Buckets Encryption (Optional)
  dynamic "statement" {
    for_each = length(var.aws_s3_buckets_kms_keys_arns) > 0 ? [1] : []
    content {
      sid = "KMSRegionalBuckets"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = var.aws_s3_buckets_kms_keys_arns
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

  # S3 - Transcribe Storage (Only if transcribe S3 bucket is different from main bucket)
  dynamic "statement" {
    for_each = var.aws_transcribe_s3_bucket != null && var.aws_transcribe_s3_bucket != local.s3_bucket_name ? [1] : []
    content {
      sid = "TranscribeS3Storage"
      actions = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ]
      resources = ["arn:aws:s3:::${var.aws_transcribe_s3_bucket}/*"]
    }
  }

  # Comprehend - Language Detection (Always Enabled)
  statement {
    sid       = "ComprehendLanguageDetection"
    actions   = ["comprehend:DetectDominantLanguage"]
    resources = ["*"]
  }

  # Translate - Text Translation (Always Enabled)
  statement {
    sid       = "TranslateTextTranslation"
    actions   = ["translate:TranslateText"]
    resources = ["*"]
  }
}

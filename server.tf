/*
Server on ECS
*/

module "server" {
  source = "JGoutin/ecs-fargate/aws"
  # 1.4 is the first release that deletes the Container Insights log group the ECS
  # service-linked role recreates after the cluster is gone, and that redeploys the
  # service when its capacity provider strategy or its secrets change.
  version                           = "~> 1.4"
  tags                              = local.apn_tags
  kms_key_id                        = module.kms_key.id
  kms_policy_dependency             = module.kms_key.policy_dependency
  subnets_ids                       = module.vpc.subnets_ids
  cloudwatch_logs_retention_in_days = var.cloudwatch_logs_retention_in_days
  container_insight                 = var.container_insight
  name_prefix                       = local.name_prefix
  security_group_ids                = compact([module.vpc.security_group_id])
  task_role_policies                = concat([aws_iam_policy.server.arn, aws_iam_policy.server_services.arn], var.ecs_task_role_policy_arns)
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
      # ECS sends SIGKILL 30s after SIGTERM by default, which would cut the
      # server's own drain short. Give it the drain window plus 10s of headroom
      # for the shutdown itself, within the 120s ECS accepts on Fargate.
      stop_timeout = var.shutdown_drain_timeout == null ? null : min(ceil(var.shutdown_drain_timeout) + 10, 120)
      environment = merge(
        { for k, v in {
          AWS_S3_BUCKET                            = local.s3_bucket_name
          AWS_POLLY_REGION                         = var.aws_polly_region
          AWS_COMPREHEND_REGION                    = var.aws_comprehend_region
          AWS_BEDROCK_REGIONS                      = var.aws_bedrock_regions != null ? join(",", var.aws_bedrock_regions) : null
          AWS_BEDROCK_MANTLE_REGIONS               = var.aws_bedrock_mantle_regions != null ? join(",", var.aws_bedrock_mantle_regions) : null
          AWS_BEDROCK_MANTLE_PREFERRED_MODELS      = var.aws_bedrock_mantle_preferred_models != null ? join(",", var.aws_bedrock_mantle_preferred_models) : null
          AWS_BEDROCK_MANTLE_PROJECT               = var.aws_bedrock_mantle_project
          AWS_BEDROCK_GUARDRAIL_IDENTIFIER         = var.aws_bedrock_guardrail_identifier
          AWS_BEDROCK_GUARDRAIL_VERSION            = var.aws_bedrock_guardrail_version
          AWS_BEDROCK_GUARDRAIL_TRACE              = var.aws_bedrock_guardrail_trace
          AWS_BEDROCK_SESSION_ENCRYPTION_KEY_ARN   = var.aws_bedrock_session_encryption_key_arn
          AWS_BEDROCK_USER_ROLE_ARN                = var.aws_bedrock_user_role_arn
          AWS_BEDROCK_USER_ROLE_SESSION_DURATION   = var.aws_bedrock_user_role_session_duration
          AWS_BEDROCK_USER_ROLE_TAG_KEY            = var.aws_bedrock_user_role_tag_key
          AWS_BEDROCK_USER_ROLE_REQUIRE_IDENTITY   = var.aws_bedrock_user_role_require_identity
          AWS_TRANSCRIBE_REGION                    = var.aws_transcribe_region
          AWS_TRANSCRIBE_S3_BUCKET                 = var.aws_transcribe_s3_bucket
          AWS_TRANSCRIBE_OUTPUT_ENCRYPTION_KEY_ARN = var.aws_transcribe_output_encryption_key_arn
          AWS_S3_TMP_PREFIX                        = var.aws_s3_tmp_prefix
          AWS_S3_FILES_PREFIX                      = var.aws_s3_files_prefix
          AWS_S3_VIDEOS_PREFIX                     = var.aws_s3_videos_prefix
          AWS_S3_BATCHES_PREFIX                    = var.aws_s3_batches_prefix
          AWS_BEDROCK_BATCH_ROLE_ARN               = local.bedrock_batch_role_arn
          AWS_S3_VECTOR_STORES_PREFIX              = var.aws_s3_vector_stores_prefix
          AWS_S3_VECTORS_BUCKET                    = local.s3_vectors_bucket_name
          AWS_S3_VECTORS_REGION                    = local.s3_vectors_bucket_name != null ? local.s3_vectors_region : null
          AWS_SQS_VECTOR_STORE_QUEUE_URL           = local.sqs_vector_store_queue_url
          AWS_BEDROCK_KNOWLEDGE_BASE_IDS           = length(var.aws_bedrock_knowledge_base_ids) > 0 ? join(",", var.aws_bedrock_knowledge_base_ids) : null
          AWS_TRANSLATE_REGION                     = var.aws_translate_region
          TIMEZONE                                 = var.timezone
          OPENAI_ROUTES_PREFIX                     = var.openai_routes_prefix
          ANTHROPIC_ROUTES_PREFIX                  = var.anthropic_routes_prefix
          COHERE_ROUTES_PREFIX                     = var.cohere_routes_prefix
          API_KEY_SSM_PARAMETER                    = var.api_key_ssm_parameter
          API_KEY_SECRETSMANAGER_SECRET            = var.api_key_secretsmanager_secret
          API_KEY_SECRETSMANAGER_KEY               = var.api_key_secretsmanager_key
          AUTHENTICATION_MODE                      = var.authentication_mode
          AWS_COGNITO_USER_POOL_ID                 = var.aws_cognito_user_pool_id
          AWS_COGNITO_CLIENT_IDS                   = var.aws_cognito_client_ids
          AWS_COGNITO_REQUIRED_SCOPES              = var.aws_cognito_required_scopes
          AWS_COGNITO_ACCEPT_ID_TOKEN              = var.aws_cognito_accept_id_token
          AWS_COGNITO_ISSUER_TYPE                  = var.aws_cognito_issuer_type
          OAUTH_RESOURCE_IDENTIFIER                = var.oauth_resource_identifier
          OAUTH_AUTHORIZATION_SERVERS              = var.oauth_authorization_servers
          OAUTH_SCOPES_SUPPORTED                   = var.oauth_scopes_supported
          OTEL_SERVICE_NAME                        = var.otel_service_name
          OTEL_EXPORTER_ENDPOINT                   = var.otel_exporter_endpoint
          LOG_LEVEL                                = var.log_level
          DEFAULT_MODEL_PARAMS                     = var.default_model_params
          DEFAULT_MODEL_SERVICE_TIERS              = var.default_model_service_tiers
          DEFAULT_TTS_MODEL                        = var.default_tts_model
          DEFAULT_TTS_LANGUAGE                     = var.default_tts_language
          TOKENS_ESTIMATION_DEFAULT_ENCODING       = var.tokens_estimation_default_encoding
          CLOUDWATCH_METRICS_NAMESPACE             = var.cloudwatch_metrics_namespace
          ANTHROPIC_BETA_ALLOWLIST                 = var.anthropic_beta_allowlist
          MCP_INCLUDE_TOOLS                        = var.mcp_include_tools
          MCP_EXCLUDE_TOOLS                        = var.mcp_exclude_tools
          AWS_BEDROCK_REGION_ROUTING               = var.aws_bedrock_region_routing
          IMAGE_GENERATION_MODEL                   = var.image_generation_model
          VECTOR_STORE_EMBEDDING_MODEL             = var.vector_store_embedding_model
          EXTRA_MODEL_PARAMS_DENYLIST              = var.extra_model_params_denylist
          # Serve IPv6 as well as IPv4, from one dual-stack socket: with IPv6 on,
          # service discovery publishes an AAAA record per task, and a client that
          # resolves it first would otherwise get a connection refused. Left at the
          # image default on IPv4-only VPCs, where no AAAA record exists.
          GRANIAN_HOST = module.vpc.ipv6_enabled ? "::" : null
        } : k => v if v != null },
        { for k, v in {
          ENABLE_MCP_STREAMABLE_HTTP                             = var.enable_mcp_streamable_http
          ENABLE_MCP_SSE                                         = var.enable_mcp_sse
          MCP_STATELESS_HTTP                                     = var.mcp_stateless_http
          AWS_S3_ACCELERATE                                      = var.aws_s3_accelerate
          AWS_BEDROCK_CROSS_REGION_INFERENCE                     = var.aws_bedrock_cross_region_inference
          AWS_BEDROCK_CROSS_REGION_INFERENCE_GLOBAL              = var.aws_bedrock_cross_region_inference_global
          AWS_BEDROCK_LEGACY                                     = var.aws_bedrock_legacy
          AWS_BEDROCK_MARKETPLACE_AUTO_SUBSCRIBE                 = var.aws_bedrock_marketplace_auto_subscribe
          AWS_BEDROCK_ALLOW_CROSS_REGION_INFERENCE_PROFILE_ARN   = var.aws_bedrock_allow_cross_region_inference_profile_arn
          AWS_BEDROCK_ALLOW_APPLICATION_INFERENCE_PROFILE_ARN    = var.aws_bedrock_allow_application_inference_profile_arn
          AWS_BEDROCK_ALLOW_PROMPT_ROUTER_ARN                    = var.aws_bedrock_allow_prompt_router_arn
          AWS_BEDROCK_ALLOW_PROMPT_ARN                           = var.aws_bedrock_allow_prompt_arn
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
          AWS_BEDROCK_ALLOW_SERVICE_TIER_OVERRIDE                = var.aws_bedrock_allow_service_tier_override
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
          SHUTDOWN_DRAIN_TIMEOUT                                 = var.shutdown_drain_timeout
          AWS_BEDROCK_DEPRECATED_MODEL_FALLBACK                  = var.aws_bedrock_deprecated_model_fallback
          AWS_S3_VIDEOS_EXPIRES_AFTER                            = var.aws_s3_videos_expires_after
          CLOUDWATCH_METRICS                                     = var.cloudwatch_metrics
          COST_TRACKING                                          = var.cost_tracking
          AWS_BEDROCK_MANTLE_ENABLED                             = var.aws_bedrock_mantle_enabled
          AWS_BEDROCK_MANTLE_SERVICE_HEADER                      = var.aws_bedrock_mantle_service_header
          AWS_BEDROCK_ALLOW_MANTLE_PROJECT_OVERRIDE              = var.aws_bedrock_allow_mantle_project_override
          AWS_BEDROCK_EXTERNAL_WEB_ACCESS                        = var.aws_bedrock_external_web_access
          AWS_BEDROCK_ALLOW_EXTERNAL_WEB_ACCESS_OVERRIDE         = var.aws_bedrock_allow_external_web_access_override
          MAX_INPUT_FILE_SIZE                                    = var.max_input_file_size
          MAX_CONCURRENT_INPUT_DOWNLOADS                         = var.max_concurrent_input_downloads
          REALTIME_ALLOW_SESSION_OVERRIDE                        = var.realtime_allow_session_override
          VECTOR_STORE_CHUNK_SIZE_TOKENS                         = var.vector_store_chunk_size_tokens
          VECTOR_STORE_CHUNK_OVERLAP_TOKENS                      = var.vector_store_chunk_overlap_tokens
          EXTRA_MODEL_PARAMS_DROP_ALL                            = var.extra_model_params_drop_all
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
          AWS_TRANSCRIBE_STREAM_LANGUAGES   = var.aws_transcribe_stream_languages
          COST_PRICE_OVERRIDES              = var.cost_price_overrides
          PROXY_TRUSTED_HOSTS               = local.proxy_trusted_hosts
        } : k => jsonencode(v) if v != null }
      )
      secrets = merge(
        var.api_key != null || var.api_key_create ? {
          API_KEY = var.api_key != null ? var.api_key : random_password.api_key[0].result
        } : {},
        # Tested on the inputs, not on the value: the generated key is unknown at
        # plan time, and comparing it to null would make the secret names unknown.
        var.realtime_client_secret_key != null || local.create_realtime_client_secret_key ? {
          REALTIME_CLIENT_SECRET_KEY = local.realtime_client_secret_key
        } : {},
      )
      port_mappings = {
        http = {
          container_port    = local.port
          target_group_arns = var.alb_enabled ? [aws_lb_target_group.main[0].arn] : null
        }
      }
      # ECS ignores the image's own HEALTHCHECK, so it is re-declared here. The
      # probe derives its Host header from TRUSTED_HOSTS, which the server
      # validates on /health like any other path.
      health_check = {
        command      = ["CMD", "python3", "-S", "-m", "stdapi.healthcheck"]
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


#: IAM's hard ceiling on the size of a managed policy document, in characters.
#  Not adjustable through Service Quotas, and whitespace does not count toward it.
locals {
  iam_managed_policy_max_characters = 6144
}

resource "aws_iam_policy" "server" {
  name   = "${local.name}-policy"
  policy = data.aws_iam_policy_document.server.json
  tags   = local.apn_tags

  # Caught at plan time, where the statement that overflowed is still in front of
  # you. Without it, IAM answers CreatePolicy with a bare "LimitExceeded: Cannot
  # exceed quota for PolicySize: 6144" halfway through an apply.
  lifecycle {
    precondition {
      condition     = length(data.aws_iam_policy_document.server.json) <= local.iam_managed_policy_max_characters
      error_message = "The Amazon Bedrock policy renders ${length(data.aws_iam_policy_document.server.json)} characters, over IAM's ${local.iam_managed_policy_max_characters}-character limit for a managed policy. Move one of its statements into a further policy rather than widening the actions of another."
    }
  }
}

resource "aws_iam_policy" "server_services" {
  name   = "${local.name}-services-policy"
  policy = data.aws_iam_policy_document.server_services.json
  tags   = local.apn_tags

  lifecycle {
    precondition {
      condition     = length(data.aws_iam_policy_document.server_services.json) <= local.iam_managed_policy_max_characters
      error_message = "The supporting-services policy renders ${length(data.aws_iam_policy_document.server_services.json)} characters, over IAM's ${local.iam_managed_policy_max_characters}-character limit for a managed policy. Move one of its statements into a further policy rather than widening the actions of another."
    }
  }
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
      "bedrock:InvokeModelWithBidirectionalStream",
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
      "bedrock:UpdateSession",
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
      # Serves /anthropic/v1/messages/count_tokens for a Mantle-served model:
      # Bedrock's own CountTokens is Anthropic-only, so the count is proxied to
      # the Mantle endpoint instead. Without it that route answers 500.
      "bedrock-mantle:CountTokens",
    ]
    resources = ["arn:aws:bedrock-mantle:*:${data.aws_caller_identity.current.account_id}:project/*"]
  }

  # Bedrock Mantle - Bearer Token Authentication (Always Required)
  statement {
    sid       = "BedrockMantleBearerToken"
    actions   = ["bedrock-mantle:CallWithBearerToken"]
    resources = ["*"]
  }

  # Bedrock Web Search - Built-in grounding tool (Always Required; the tool only
  # runs when a request asks for it). ExternalWebAccess is granted only when
  # aws_bedrock_external_web_access is enabled: without it every search is
  # answered from the in-AWS index and cache.
  statement {
    sid = "BedrockWebSearch"
    actions = concat(
      [
        "bedrock-websearch:InvokeSearch",
        "bedrock-websearch:InvokeFetch",
      ],
      var.aws_bedrock_external_web_access == true ? ["bedrock-websearch:ExternalWebAccess"] : [],
    )
    resources = ["arn:aws:bedrock-websearch:*:*:*"]
  }

  # Bedrock - Batch Inference (Optional)
  # The server submits, polls and cancels its own jobs; Amazon Bedrock runs them under the batch
  # service role, so the models are invoked by that role and not by this one. The submitted
  # requests and the results are S3 objects, covered by the S3 File Storage statements above.
  dynamic "statement" {
    for_each = local.bedrock_batch_role_arn != null ? [1] : []
    content {
      sid = "BedrockBatchJobs"
      actions = [
        "bedrock:CreateModelInvocationJob",
        "bedrock:GetModelInvocationJob",
        "bedrock:StopModelInvocationJob",
      ]
      resources = ["arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:model-invocation-job/*"]
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

  # Bedrock - Prompt Management (Optional)
  # GetPrompt resolves the model bound to the prompt variant, RenderPrompt fills
  # its variables in.
  dynamic "statement" {
    for_each = var.aws_bedrock_allow_prompt_arn == true ? [1] : []
    content {
      sid = "BedrockPromptManagement"
      actions = [
        "bedrock:GetPrompt",
        "bedrock:RenderPrompt",
      ]
      resources = ["arn:aws:bedrock:*:*:prompt/*"]
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

  # Bedrock - Knowledge Base Vector Stores (Optional)
  # The knowledge base is the customer's, so no create, update or delete action on it is granted,
  # only the documents of its data source. bedrock:ListKnowledgeBases is deliberately absent: the
  # server never discovers a knowledge base it was not given, so only the allowlisted ones are
  # ever addressed.
  dynamic "statement" {
    for_each = length(var.aws_bedrock_knowledge_base_ids) > 0 ? [1] : []
    content {
      sid = "BedrockKnowledgeBaseVectorStores"
      actions = [
        "bedrock:GetKnowledgeBase",
        "bedrock:Retrieve",
        "bedrock:ListDataSources",
        "bedrock:IngestKnowledgeBaseDocuments",
        "bedrock:ListKnowledgeBaseDocuments",
        "bedrock:GetKnowledgeBaseDocuments",
        "bedrock:DeleteKnowledgeBaseDocuments",
      ]
      # The knowledge base is read in the first Bedrock region. An entry may name its data source
      # as '<knowledgeBaseId>/<dataSourceId>', which is not part of the knowledge base ARN.
      resources = [
        for entry in var.aws_bedrock_knowledge_base_ids :
        "arn:aws:bedrock:${local.candidate_regions[0]}:${data.aws_caller_identity.current.account_id}:knowledge-base/${split("/", entry)[0]}"
      ]
    }
  }
}

# Everything the gateway calls that is not Amazon Bedrock itself. It is a
# separate document, and a separate managed policy, only because IAM caps a
# managed policy at 6,144 characters and the two together exceed that: with the
# storage, vector, queue and speech features enabled the combined document
# rendered 6,535 characters and CreatePolicy refused it. The split is by service
# so that neither half can ever be empty -- the Polly, Comprehend and Translate
# statements below are granted unconditionally.
data "aws_iam_policy_document" "server_services" {

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

  # IAM - Batch Service Role Hand-Off (Optional)
  # Creating a job hands the service role to Amazon Bedrock, which requires iam:PassRole. Scoped to
  # that one role and to that one service: a wider grant would let the task role hand any role it
  # can name to Amazon Bedrock and inherit its permissions.
  dynamic "statement" {
    for_each = local.bedrock_batch_role_arn != null ? [1] : []
    content {
      sid       = "BedrockBatchPassRole"
      actions   = ["iam:PassRole"]
      resources = [local.bedrock_batch_role_arn]
      condition {
        test     = "StringEquals"
        variable = "iam:PassedToService"
        values   = ["bedrock.amazonaws.com"]
      }
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

  # STS - Per-end-user cost attribution (Optional)
  # Scoped to the single configured role: the server opens one session of it per
  # end user. Tagging the session is a separate action from assuming the role,
  # and the role's own trust policy must allow both.
  dynamic "statement" {
    for_each = var.aws_bedrock_user_role_arn != null ? [1] : []
    content {
      sid = "EndUserRoleSessions"
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
      resources = [var.aws_bedrock_user_role_arn]
    }
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

  # S3 Vectors - Vector Stores API (Optional)
  # The gateway never creates or deletes the vector bucket, only the indexes inside it, so no
  # bucket-level create or delete action is granted. The stores' own records are JSON objects in
  # the general purpose bucket, covered by the S3 File Storage statements above.
  dynamic "statement" {
    for_each = local.s3_vectors_bucket_name != null ? [1] : []
    content {
      sid = "VectorStoreIndexes"
      actions = [
        "s3vectors:CreateIndex",
        "s3vectors:DeleteIndex",
        "s3vectors:PutVectors",
        "s3vectors:GetVectors",
        "s3vectors:QueryVectors",
        "s3vectors:DeleteVectors",
      ]
      resources = [
        "arn:aws:s3vectors:${local.s3_vectors_region}:${data.aws_caller_identity.current.account_id}:bucket/${local.s3_vectors_bucket_name}",
        "arn:aws:s3vectors:${local.s3_vectors_region}:${data.aws_caller_identity.current.account_id}:bucket/${local.s3_vectors_bucket_name}/index/*",
      ]
    }
  }

  # KMS - Vector Bucket Encryption (Optional)
  dynamic "statement" {
    for_each = local.s3_vectors_bucket_name != null && local.s3_vectors_kms_key_arn != null ? [1] : []
    content {
      sid = "KMSVectorBucket"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = [local.s3_vectors_kms_key_arn]
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["s3vectors.${local.s3_vectors_region}.amazonaws.com"]
      }
    }
  }

  # SQS - Durable Vector Store Indexing (Optional)
  # The server writes an indexing job to this one queue and reads it back, extending the delivery
  # while it works. It never creates, deletes or reconfigures a queue, so no management action is
  # granted; GetQueueAttributes is read-only and is what lets it honour the queue's own redrive
  # policy. The dead-letter queue is written by Amazon SQS itself and never read by the server, so
  # it is granted nothing.
  dynamic "statement" {
    for_each = local.sqs_vector_store_enabled ? [1] : []
    content {
      sid = "VectorStoreIndexingQueue"
      actions = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:GetQueueAttributes",
      ]
      resources = [local.sqs_vector_store_queue_arn]
    }
  }

  # KMS - Vector Store Indexing Queue Encryption (Optional)
  # Amazon SQS calls AWS KMS under the task role's own identity, so the grant is conditioned on
  # the call arriving through Amazon SQS in the region the queue lives in.
  dynamic "statement" {
    for_each = local.sqs_vector_store_enabled && local.sqs_vector_store_queue_kms_key_arn != null ? [1] : []
    content {
      sid = "KMSVectorStoreIndexingQueue"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = [local.sqs_vector_store_queue_kms_key_arn]
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["sqs.${local.sqs_vector_store_queue_region}.amazonaws.com"]
      }
    }
  }

  # Polly - Text-to-Speech (Always Enabled)
  # StartSpeechSynthesisStream serves input above the single-call limit with a
  # generative voice, which needs no bucket. Like SynthesizeSpeech, the only
  # resource type it accepts is a lexicon ARN, which would restrict
  # pronunciation lexicons rather than the synthesis itself.
  statement {
    sid = "PollyTextToSpeech"
    actions = [
      "polly:SynthesizeSpeech",
      "polly:StartSpeechSynthesisStream",
      "polly:DescribeVoices"
    ]
    resources = ["*"]
  }

  # Polly - Long Input Synthesis (Only if S3 bucket available)
  # Wildcard resource: GetSpeechSynthesisTask declares no resource type at all,
  # and the only one StartSpeechSynthesisTask accepts is a lexicon ARN, which
  # would restrict pronunciation lexicons rather than the tasks themselves.
  # The synthesis output is confined by the S3 statements above.
  dynamic "statement" {
    for_each = local.s3_bucket_name != null || length(local.regional_buckets_combined) > 0 ? [1] : []
    content {
      sid = "PollyLongInputSynthesis"
      actions = [
        "polly:StartSpeechSynthesisTask",
        "polly:GetSpeechSynthesisTask"
      ]
      resources = ["*"]
    }
  }

  # Transcribe - Speech-to-Text (Only if S3 bucket available)
  dynamic "statement" {
    for_each = local.s3_bucket_name != null || var.aws_transcribe_s3_bucket != null ? [1] : []
    content {
      sid = "TranscribeSpeechToText"
      actions = [
        "transcribe:StartTranscriptionJob",
        "transcribe:GetTranscriptionJob",
        "transcribe:DeleteTranscriptionJob",
        "transcribe:StartStreamTranscription"
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

  # Transcribe - Output Encryption KMS (Optional)
  dynamic "statement" {
    for_each = var.aws_transcribe_output_encryption_key_arn != null ? [1] : []
    content {
      sid = "TranscribeOutputEncryption"
      actions = [
        "kms:GenerateDataKey",
        "kms:Decrypt",
      ]
      resources = [var.aws_transcribe_output_encryption_key_arn]
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
  # ListLanguages has no resource-level ARN. It is read once at startup to refuse an
  # unsupported language pair before the call; without it the check is simply skipped.
  statement {
    sid = "TranslateTextTranslation"
    actions = [
      "translate:TranslateText",
      "translate:ListLanguages",
    ]
    resources = ["*"]
  }
}

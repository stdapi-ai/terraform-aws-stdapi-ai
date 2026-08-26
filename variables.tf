# Global configuration

variable "name_prefix" {
  description = "Prefix to add to all created resources names."
  type        = string
  default     = "stdapiai"
}

# Application Configuration

variable "aws_s3_bucket_create" {
  description = "If true, create an S3 bucket for the application. Only used when aws_s3_bucket is not specified. When aws_s3_bucket is specified, this value is ignored."
  type        = bool
  default     = true
}

variable "aws_adaptive_retry" {
  description = "Enable adaptive retry mode for all AWS service calls. When enabled, the client dynamically adjusts its retry behavior based on observed error rates, slowing down when a service appears congested. Default to false."
  type        = bool
  default     = null
}

variable "aws_max_pool_connections" {
  description = "Maximum number of concurrent HTTP connections per AWS service client. Each AWS service client (per region) maintains its own connection pool up to this limit. Increase if you observe connection pool exhaustion under high concurrency. Default to 50."
  type        = number
  default     = null
}

variable "aws_connect_timeout" {
  description = "Timeout in seconds for establishing a connection to an AWS service endpoint. Keeping this value short allows fast failover to another region when a connection cannot be established. Default to 5."
  type        = number
  default     = null
}

variable "aws_s3_bucket" {
  description = "Existing S3 bucket name for storing generated files and application data. When specified, takes precedence over aws_s3_bucket_create. If not specified and aws_s3_bucket_create is true, a bucket will be created automatically."
  type        = string
  default     = null
}

variable "aws_s3_regional_buckets" {
  description = <<-EOT
    By default (`aws_s3_regional_buckets_create = true`), buckets are created automatically for every region in `aws_bedrock_regions` not listed here. Use this variable only to point to **existing** buckets you manage yourself.

    Keys are AWS region identifiers, values are bucket names.

    Example: { "us-east-1" = "my-bucket-us-east-1", "us-west-2" = "my-bucket-us-west-2" }

    Required for Bedrock operations with multimodal input or document processing.
  EOT
  type        = map(string)
  default     = null
}

variable "aws_s3_regional_buckets_create" {
  description = <<-EOT
    If true (default), create regional S3 buckets and per-region KMS keys for every region in `aws_bedrock_regions`
    not already present as a key of `aws_s3_regional_buckets` and not equal to the provider's primary region.

    Set to false to disable automatic creation (for example, if you manage these buckets out-of-band).
  EOT
  type        = bool
  default     = true
}

variable "aws_s3_buckets_kms_keys_arns" {
  description = <<-EOT
    List of KMS key ARNs used to encrypt user-provided regional S3 buckets specified in `aws_s3_regional_buckets`.
    Required to grant the server permissions to access encrypted regional buckets.
    When using `aws_s3_regional_buckets_create = true` (default), KMS keys are created automatically and do not need to be specified here.
  EOT
  type        = list(string)
  default     = []
}

variable "aws_bedrock_allow_cross_region_inference_profile_arn" {
  description = "If True, allow users to pass cross-region inference profile ARNs directly as model IDs. Cross-region inference profiles enable routing to multiple regions for better availability. When disabled, only standard model IDs and configured profiles are accepted."
  type        = bool
  default     = null
}

variable "aws_bedrock_allow_application_inference_profile_arn" {
  description = "If True, allow users to pass application inference profile ARNs directly as model IDs. Application inference profiles are custom routing configurations for specific use cases. When disabled, only standard model IDs and configured profiles are accepted."
  type        = bool
  default     = null
}

variable "aws_bedrock_allow_prompt_router_arn" {
  description = "If True, allow users to pass prompt router ARNs directly as model IDs. Prompt routers enable dynamic model selection based on prompt characteristics. When disabled, only standard model IDs and configured profiles are accepted."
  type        = bool
  default     = null
}

variable "aws_bedrock_allow_prompt_arn" {
  description = "If true, allow users to reference an Amazon Bedrock Prompt Management prompt ARN in the OpenAI Responses API 'prompt.id' parameter, for example 'arn:aws:bedrock:us-east-1:123456789012:prompt/ABCDE12345:1'. The prompt template is rendered by Amazon Bedrock and its variables are filled from 'prompt.variables'. Setting it to true also grants the task role bedrock:GetPrompt and bedrock:RenderPrompt on every prompt of the account. Default to false, which rejects any 'prompt' parameter with a 400 error."
  type        = bool
  default     = null
}

variable "aws_bedrock_model_arn_mapping" {
  description = <<-EOT
    Map standard model IDs to custom inference profile or prompt router ARNs. This allows server administrators to override the default cross-region inference profiles with custom application inference profiles, cross-region inference profiles, or prompt routers.

    Supported ARN types:
    - Cross-region inference profile: arn:aws:bedrock:REGION:ACCOUNT:inference-profile/ID
    - Application inference profile: arn:aws:bedrock:REGION:ACCOUNT:application-inference-profile/ID
    - Prompt router: arn:aws:bedrock:REGION:ACCOUNT:default-prompt-router/ID

    Example: {
      "anthropic.claude-3-5-sonnet-20241022-v2:0" = "arn:aws:bedrock:us-east-1:123456789012:application-inference-profile/my-custom-profile"
      "anthropic.claude-haiku-4-5-20251001-v1:0" = "arn:aws:bedrock:us-east-1:123456789012:default-prompt-router/my-router"
    }
  EOT
  type        = map(string)
  default     = null
}

variable "aws_s3_accelerate" {
  description = "Enable S3 Transfer Acceleration for presigned URLs. Default to false."
  type        = bool
  default     = null
}

variable "aws_polly_region" {
  description = "AWS region for Polly text-to-speech service. Default to every var.aws_bedrock_regions region as a failover candidate, or the current region."
  type        = string
  default     = null
}

variable "aws_comprehend_region" {
  description = "AWS region for Comprehend language detection service. Default to every var.aws_bedrock_regions region as a failover candidate, or the current region."
  type        = string
  default     = null
}

variable "aws_bedrock_regions" {
  description = "List of AWS regions where Bedrock AI models are available. Default to the current region."
  type        = list(string)
  default     = null
}

variable "aws_bedrock_mantle_enabled" {
  description = "If true (application default), expose models served by the Amazon Bedrock Mantle endpoint (OpenAI GPT, xAI Grok, Google Gemma, and more) in addition to the classic Bedrock Converse models. Set to false to disable Mantle. When enabled but Mantle is unreachable or the region lacks the service, Mantle models are simply not listed."
  type        = bool
  default     = null
}

variable "aws_bedrock_mantle_regions" {
  description = "List of AWS regions used for Amazon Bedrock Mantle, in failover priority order. Default to var.aws_bedrock_regions."
  type        = list(string)
  default     = null
}

variable "aws_bedrock_mantle_preferred_models" {
  description = "Model IDs (or ID prefixes) served by Amazon Bedrock Mantle even when also available on the classic bedrock-runtime endpoint. Default to none (bedrock-runtime preferred)."
  type        = list(string)
  default     = null
}

variable "aws_bedrock_mantle_service_header" {
  description = "If true, honor the 'x-stdapi-service: bedrock-mantle' request header to route a dual-homed model through Bedrock Mantle for that request. Cannot be combined with Bedrock Guardrails. Default to false."
  type        = bool
  default     = null
}

variable "aws_bedrock_mantle_project" {
  description = "Default Amazon Bedrock Mantle project (workspace) ID used to attribute Mantle inference requests for cost tracking and observability. A bare project ID such as 'proj_abc123' or 'default' (not an ARN). Default to none."
  type        = string
  default     = null
}

variable "aws_bedrock_allow_mantle_project_override" {
  description = "If true, allow clients to override the configured Amazon Bedrock Mantle project per request via the 'OpenAI-Project' / 'anthropic-workspace' header. Default to false."
  type        = bool
  default     = null
}

variable "aws_bedrock_user_role_arn" {
  description = "ARN of an IAM role the server assumes once per end user, so AWS reports Amazon Bedrock model usage per end user in Cost Explorer and the Cost and Usage Report. The role's trust policy must allow this module's task role to call both 'sts:AssumeRole' and 'sts:TagSession' on it; this module grants the task role those two actions on this ARN. Default to none (all usage reported under the task role)."
  type        = string
  default     = null

  validation {
    condition     = var.aws_bedrock_user_role_arn == null || can(regex("^arn:aws(-[a-z]+)*:iam::[0-9]{12}:role/", var.aws_bedrock_user_role_arn))
    error_message = "Must be an IAM role ARN, arn:<partition>:iam::<account-id>:role/<name>."
  }
}

variable "aws_bedrock_user_role_session_duration" {
  description = "Lifetime in seconds of a per-end-user role session obtained with aws_bedrock_user_role_arn, from 900 to 3600. The ceiling is imposed by AWS: a role session obtained from another role session cannot last longer than one hour. Default to 3600."
  type        = number
  default     = null

  validation {
    condition     = var.aws_bedrock_user_role_session_duration == null || try(var.aws_bedrock_user_role_session_duration >= 900 && var.aws_bedrock_user_role_session_duration <= 3600, false)
    error_message = "Must be between 900 and 3600 seconds."
  }
}

variable "aws_bedrock_user_role_tag_key" {
  description = "Session tag key carrying the end user identity on per-end-user role sessions. Activate it as a cost allocation tag of type 'IAM principal' to group Bedrock costs per end user, and test it in IAM policies as 'aws:PrincipalTag/<key>'. Default to 'user'."
  type        = string
  default     = null
}

variable "aws_bedrock_user_role_require_identity" {
  description = "If true, reject a model request that identifies no end user instead of running it under the server's own identity. Requires aws_bedrock_user_role_arn. Default to false."
  type        = bool
  default     = null
}

variable "aws_bedrock_external_web_access" {
  description = "If true, let the built-in web search tool reach the public web instead of answering from the Amazon Bedrock web index and cache. Requires the 'bedrock-websearch:ExternalWebAccess' IAM permission, granted by this module when enabled. Default to false."
  type        = bool
  default     = null
}

variable "aws_bedrock_allow_external_web_access_override" {
  description = "If true, allow clients to override aws_bedrock_external_web_access per request with the web search tool's 'external_web_access' field. When false, a request that sets a different value is rejected. Default to false."
  type        = bool
  default     = null
}

variable "aws_bedrock_region_routing" {
  description = "Automatic region routing strategy for Bedrock invocations. Distributes requests across configured regions to handle quota limits and regional unavailability. Strategies: 'disabled' (no routing), 'ordered' (try regions in configured order, default), 'lowest_latency' (prefer region with lowest measured latency), 'round_robin' (distribute evenly, incompatible with prompt caching). Requires at least 2 regions in aws_bedrock_regions."
  type        = string
  default     = null
  validation {
    condition     = var.aws_bedrock_region_routing == null || contains(["disabled", "ordered", "lowest_latency", "round_robin"], var.aws_bedrock_region_routing)
    error_message = "Must be one of: disabled, ordered, lowest_latency, round_robin, or null."
  }
}

variable "aws_bedrock_region_routing_quota_backoff_seconds" {
  description = "Seconds to avoid a region after receiving a quota/throttling error. Only effective when aws_bedrock_region_routing is not 'disabled'. Default to 60."
  type        = number
  default     = null
}

variable "aws_bedrock_region_routing_unavailable_backoff_seconds" {
  description = "Seconds to avoid a region after receiving an unavailability error. Only effective when aws_bedrock_region_routing is not 'disabled'. Default to 30."
  type        = number
  default     = null
}

variable "aws_bedrock_region_routing_max_quota_backoff_seconds" {
  description = "Hard ceiling in seconds on the exponential quota backoff for a single region. Quota backoff doubles on each consecutive error; this value caps how high it can grow. Only effective when aws_bedrock_region_routing is not 'disabled'. Default to 3600 (1 hour)."
  type        = number
  default     = null
}

variable "aws_bedrock_region_routing_quota_stale_factor" {
  description = "Multiplier applied to the max quota backoff to compute the stale-error threshold. If the most recent quota error for a region is older than (max_quota_backoff * factor) seconds, the consecutive-error counter is reset. Only effective when aws_bedrock_region_routing is not 'disabled'. Default to 2."
  type        = number
  default     = null
}

variable "aws_bedrock_max_retries" {
  description = "Maximum number of retries for Bedrock invocations. When region routing is enabled, retries cycle through all available regions. Default to 9."
  type        = number
  default     = null
}

variable "aws_failover_max_retries" {
  description = "Maximum SDK retry attempts per candidate region for the multi-region failover services (Polly, Transcribe, Translate, Comprehend). Only applied when the service has several candidate regions (no dedicated region setting configured). Default to 2."
  type        = number
  default     = null
  validation {
    condition     = var.aws_failover_max_retries == null || var.aws_failover_max_retries >= 0
    error_message = "Must be greater than or equal to 0."
  }
}

variable "aws_s3_accepted_buckets" {
  description = <<-EOT
    S3 buckets that the application has read access to, mapped to their region. These buckets can be used as input S3 data sources, and S3 HTTP URLs (including presigned URLs) for these buckets will be automatically converted to S3 URIs for direct access.

    Keys are bucket names, values are AWS region identifiers.

    Example: { "my-data-bucket" = "us-east-1", "my-eu-bucket" = "eu-west-1" }

    If not specified, only the application's own S3 buckets (aws_s3_bucket and aws_s3_regional_buckets) are recognized for S3 URI conversion.
  EOT
  type        = map(string)
  default     = null
}

variable "aws_s3_accepted_buckets_kms_key_arn" {
  description = "List of KMS key ARNs used to encrypt the accepted S3 buckets (var.aws_s3_accepted_buckets). Required to grant the server permissions to decrypt objects from KMS-encrypted accepted buckets."
  type        = list(string)
  default     = null
}

variable "aws_bedrock_model_region_restrict" {
  description = <<-EOT
    Restrict a model to specific region(s) only. Can be used when a model provides important features only in certain regions.

    Keys are Bedrock model IDs (or prefixes), values are ordered lists of allowed regions. When set, the model will only be available in the listed regions (intersected with the regions where it is actually available).

    Example: { "amazon.nova-pro-v1:0" = ["us-east-1"] }

    Use case: Nova grounding is only available in us-east-1, so restricting nova-pro to us-east-1 ensures grounding always works.
  EOT
  type        = map(list(string))
  default     = null
}

variable "aws_bedrock_cross_region_inference" {
  description = "If true, allow cross region inference to be used. Default to true."
  type        = bool
  default     = null
}

variable "aws_bedrock_cross_region_inference_global" {
  description = "If True, allow 'global' cross region inference that can route requests to any region, worldwide. Default to true."
  type        = bool
  default     = null
}

variable "aws_bedrock_legacy" {
  description = "If true, allow legacy Bedrock models to be used. Default to false."
  type        = bool
  default     = null
}

variable "aws_bedrock_deprecated_model_fallback" {
  description = "If true, requests that use a deprecated model ID are transparently retried with the recommended replacement model instead of returning a 404 error. Disable if you want deprecated model IDs to fail explicitly so clients are forced to migrate. Default to true."
  type        = bool
  default     = null
}

variable "aws_bedrock_deprecated_models" {
  description = <<-EOT
    Additional deprecated model ID mappings, merged with the built-in deprecation registry at startup. User-provided entries take precedence over built-in ones.

    Keys are deprecated model IDs, values are the recommended replacement model IDs.

    Example: { "my-old-model-v1" = "my-new-model-v2" }
  EOT
  type        = map(string)
  default     = null
}

variable "aws_bedrock_marketplace_auto_subscribe" {
  description = "If true, allow the server to automatically subscribe to new models in the AWS Marketplace. Default to true."
  type        = bool
  default     = null
}

variable "aws_bedrock_guardrail_identifier" {
  description = "Amazon Bedrock Guardrails ID."
  type        = string
  default     = null
}

variable "aws_bedrock_guardrail_version" {
  description = "Amazon Bedrock Guardrails version."
  type        = string
  default     = null
}

variable "aws_bedrock_guardrail_trace" {
  description = "Amazon Bedrock Guardrails trace setting: disabled, enabled, or enabled_full."
  type        = string
  default     = null
  validation {
    condition     = var.aws_bedrock_guardrail_trace == null || contains(["disabled", "enabled", "enabled_full"], var.aws_bedrock_guardrail_trace)
    error_message = "Must be one of: disabled, enabled, enabled_full, or null."
  }
}

variable "aws_transcribe_region" {
  description = "AWS region for Transcribe speech-to-text service. Default to every var.aws_bedrock_regions region as a failover candidate, or the current region."
  type        = string
  default     = null
}

variable "aws_transcribe_s3_bucket" {
  description = "AWS S3 bucket name for temporary file storage during transcription. Defaults to aws_s3_bucket if not specified."
  type        = string
  default     = null
}

variable "aws_transcribe_stream_languages" {
  description = "Languages a streamed transcription (stream=true) picks between when the request names none, as two or more language codes, for example ['en-US', 'es-US', 'fr-FR']. A streamed transcription starts before the recording has been fully read, which requires knowing which languages to expect. Default to none, meaning a request naming no language is transcribed once the whole recording has been read, and its language detected."
  type        = list(string)
  default     = null
}

variable "aws_transcribe_output_encryption_key_arn" {
  description = "KMS key ARN encrypting the transcription job output written to aws_transcribe_s3_bucket. The key must be usable from every region a transcription job can be served from; this module grants the task role kms:GenerateDataKey and kms:Decrypt on it, and the key policy must allow the same actions. Default to the bucket's own default encryption."
  type        = string
  default     = null
}

variable "aws_s3_tmp_prefix" {
  description = "S3 prefix (folder path) for temporary files used during job processing. Default to 'tmp/'."
  type        = string
  default     = null
}

variable "aws_s3_files_prefix" {
  description = "S3 prefix (folder path) for Files API objects. Default to 'files/'."
  type        = string
  default     = null
}

variable "aws_s3_videos_prefix" {
  description = "S3 prefix (folder path) for videos generated through the Videos API. Default to 'videos/'."
  type        = string
  default     = null
}

variable "aws_s3_videos_expires_after" {
  description = "Retention period in seconds for generated videos. When set, Video.expires_at is reported, expired downloads return 404, and a matching S3 Lifecycle expiration rule is created on the module-managed buckets. Default to no expiry."
  type        = number
  default     = null
}

variable "aws_s3_batches_prefix" {
  description = "S3 prefix (folder path) for the Batch API's own data — the submitted requests, the results and the batch records themselves. Each batch stores its data under a folder of its own below this prefix, in the bucket that served it, and the batch service role is granted access to this prefix alone. Must not be the bucket root. Default to 'batches/'."
  type        = string
  default     = null
}

variable "aws_bedrock_batch_role_create" {
  description = "If true, create the IAM service role Amazon Bedrock assumes to run batch inference jobs, allowed to read the submitted requests and write the results under aws_s3_batches_prefix in the module-managed buckets, and to invoke foundation models and inference profiles. Only used when aws_bedrock_batch_role_arn is not specified. When aws_bedrock_batch_role_arn is specified, this value is ignored. Default to false (Batch API disabled)."
  type        = bool
  default     = false
}

variable "aws_bedrock_batch_role_arn" {
  description = "ARN of an existing IAM service role Amazon Bedrock assumes to run batch inference jobs. Its trust policy must allow 'bedrock.amazonaws.com' to assume it, and it must be able to read and write every bucket the server may use, under aws_s3_batches_prefix; this module grants the task role 'iam:PassRole' on this ARN alone, for Amazon Bedrock only. When specified, takes precedence over aws_bedrock_batch_role_create. Default to none, meaning a role is created when aws_bedrock_batch_role_create is true, and the Batch API is disabled otherwise."
  type        = string
  default     = null

  validation {
    condition     = var.aws_bedrock_batch_role_arn == null || can(regex("^arn:aws(-[a-z]+)*:iam::[0-9]{12}:role/", var.aws_bedrock_batch_role_arn))
    error_message = "Must be an IAM role ARN, arn:<partition>:iam::<account-id>:role/<name>."
  }
}

variable "aws_s3_vector_stores_prefix" {
  description = "S3 prefix (folder path) in the general purpose bucket for the Vector Stores API's own records — the stores, their attached files and their file batches. Default to 'vector_stores/'."
  type        = string
  default     = null
}

variable "aws_s3_vectors_bucket_create" {
  description = "If true, create an S3 vector bucket backing the Vector Stores API. Only used when aws_s3_vectors_bucket is not specified. When aws_s3_vectors_bucket is specified, this value is ignored. Default to false (Vector Stores API disabled)."
  type        = bool
  default     = false
}

variable "aws_s3_vectors_bucket" {
  description = "Existing Amazon S3 vector bucket name backing the Vector Stores API. A vector bucket is a distinct resource type from a general purpose bucket. When specified, takes precedence over aws_s3_vectors_bucket_create. Default to none, meaning a bucket is created when aws_s3_vectors_bucket_create is true, and the Vector Stores API is disabled otherwise."
  type        = string
  default     = null
}

variable "aws_s3_vectors_region" {
  description = <<-EOT
    AWS region holding the vector bucket. A vector bucket is a regional resource and its indexes are only reachable in that region, so this setting has no failover. Default to the region this module is deployed in.

    Amazon S3 Vectors is not available in every region: see [AWS Regions, endpoints, and quotas for S3 Vectors](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-vectors-regions-quotas.html).
  EOT
  type        = string
  default     = null

  validation {
    condition = var.aws_s3_vectors_region == null || contains([
      "af-south-1", "ap-east-1", "ap-east-2", "ap-northeast-1", "ap-northeast-2", "ap-northeast-3",
      "ap-south-1", "ap-south-2", "ap-southeast-1", "ap-southeast-2", "ap-southeast-3",
      "ap-southeast-4", "ap-southeast-5", "ap-southeast-6", "ap-southeast-7", "ca-central-1",
      "ca-west-1", "eu-central-1", "eu-central-2", "eu-north-1", "eu-south-1", "eu-south-2",
      "eu-west-1", "eu-west-2", "eu-west-3", "eusc-de-east-1", "mx-central-1", "sa-east-1",
      "us-east-1", "us-east-2", "us-gov-east-1", "us-gov-west-1", "us-west-1", "us-west-2",
    ], var.aws_s3_vectors_region)
    error_message = "Amazon S3 Vectors is not available in var.aws_s3_vectors_region."
  }
}

variable "aws_s3_vectors_kms_key_arn" {
  description = "KMS key ARN encrypting the vector bucket specified in aws_s3_vectors_bucket. Required to grant the server permission to use an SSE-KMS encrypted vector bucket. When using aws_s3_vectors_bucket_create = true, a key is created automatically and does not need to be specified here."
  type        = string
  default     = null
}

variable "aws_sqs_vector_store_queue_create" {
  description = "If true, create the Amazon SQS queue, and its dead-letter queue, that make vector store indexing durable: a file attached to a store keeps being indexed by another task when the task that accepted it stops, instead of being reported as failed. Only used when the Vector Stores API is enabled and aws_sqs_vector_store_queue_url is not specified. When aws_sqs_vector_store_queue_url is specified, this value is ignored. Default to true."
  type        = bool
  default     = true
}

variable "aws_sqs_vector_store_queue_url" {
  description = "URL of an existing Amazon SQS queue carrying the vector store indexing jobs. Must be a standard queue, never FIFO, and must have a dead-letter queue: a file the server cannot index is settled as failed once its deliveries run out, and its message is kept in the dead-letter queue. The queue is reached in the single region its URL names, and only ever carries identifiers, never file content. Requires the Vector Stores API to be enabled: the server refuses to start with a queue and nothing to index. When specified, takes precedence over aws_sqs_vector_store_queue_create. Default to none, meaning a queue is created when aws_sqs_vector_store_queue_create is true and the Vector Stores API is enabled, and indexing runs in the task that accepted the request otherwise."
  type        = string
  default     = null

  validation {
    condition     = var.aws_sqs_vector_store_queue_url == null || can(regex("^https://sqs\\.[a-z0-9-]{1,32}\\.[a-z0-9.-]{1,64}/[0-9]{12}/[A-Za-z0-9_-]{1,80}$", var.aws_sqs_vector_store_queue_url))
    error_message = "Must be an Amazon SQS queue URL of the form 'https://sqs.<region>.<endpoint>/<account-id>/<queue-name>'. FIFO queues are not supported: content-based deduplication would silently drop a legitimate re-attach of the same files."
  }
}

variable "aws_sqs_vector_store_queue_kms_key_arn" {
  description = "KMS key ARN encrypting the queue specified in aws_sqs_vector_store_queue_url. Required to grant the server permission to use an SSE-KMS encrypted queue; leave unset for a queue encrypted with the Amazon SQS managed key. When using aws_sqs_vector_store_queue_create = true, the deployment key is used automatically and does not need to be specified here."
  type        = string
  default     = null
}

variable "vector_store_embedding_model" {
  description = "Model used to embed the files indexed into a vector store, and the queries searched against them. The model is frozen on each store when it is created, so changing it only affects stores created afterwards; existing stores keep answering with the model they were created with. Default to 'amazon.titan-embed-text-v2:0'."
  type        = string
  default     = null
}

variable "vector_store_chunk_size_tokens" {
  description = "Default chunk size, in tokens, for files indexed into a vector store without an explicit chunking_strategy; a request's own chunking_strategy always wins. Tokens are approximated from the text length, and a chunk is additionally capped by what the embedding model accepts in one input. Default to 800."
  type        = number
  default     = null

  validation {
    condition     = var.vector_store_chunk_size_tokens == null || (var.vector_store_chunk_size_tokens >= 100 && var.vector_store_chunk_size_tokens <= 4096)
    error_message = "Must be between 100 and 4096 tokens."
  }
}

variable "vector_store_chunk_overlap_tokens" {
  description = "Default number of tokens shared between consecutive chunks, for files indexed into a vector store without an explicit chunking_strategy. Must not exceed half of vector_store_chunk_size_tokens, which the server checks on startup. Default to 400."
  type        = number
  default     = null

  validation {
    condition     = var.vector_store_chunk_overlap_tokens == null || var.vector_store_chunk_overlap_tokens >= 0
    error_message = "Must not be negative."
  }
}

variable "aws_bedrock_knowledge_base_ids" {
  description = <<-EOT
    Allowlist of Amazon Bedrock knowledge bases served through the Vector Stores API. Each allowlisted knowledge base is addressed as the vector store `vs_kb_<knowledgeBaseId>` on every `/v1/vector_stores` endpoint and is listed alongside the stores the server owns: searching runs against it, attaching a file ingests a document, listing and reading files report its documents back, and deleting a file deletes the document.

    Write each entry as `<knowledgeBaseId>`, or as `<knowledgeBaseId>/<dataSourceId>` when the knowledge base has more than one data source; with a single data source the server resolves it itself. For example `["ABCDE12345", "FGHIJ67890/KLMNO13579"]`. Each knowledge base must live in the first `aws_bedrock_regions` region, which is the region this module grants access to it in.

    The knowledge base stays yours: this module never creates or deletes one, and the task role is granted no action that would reshape it, only `bedrock:Retrieve` and the document actions of its data source, on the ARN of each listed knowledge base.

    Default to an empty list, which grants no permission on any knowledge base and makes none of them addressable: a `vs_kb_...` identifier is then answered exactly as an unknown vector store is.
  EOT
  type        = list(string)
  default     = []
}

variable "aws_translate_region" {
  description = "AWS region for Translate text translation service. Default to every var.aws_bedrock_regions region as a failover candidate, or the current region."
  type        = string
  default     = null
}

variable "aws_dynamodb_table_create" {
  description = "If true, create a shared DynamoDB table for the server's internal state. Only used when aws_dynamodb_table is not specified. When aws_dynamodb_table is specified, this value is ignored. Default to false (table not created)."
  type        = bool
  default     = false
}

variable "aws_dynamodb_table" {
  description = "Existing DynamoDB table name backing the server's internal state. When specified, takes precedence over aws_dynamodb_table_create. If not specified and aws_dynamodb_table_create is true, a table will be created automatically."
  type        = string
  default     = null
}

variable "aws_dynamodb_table_kms_key_arn" {
  description = "KMS key ARN encrypting the DynamoDB table specified in aws_dynamodb_table, or created by aws_dynamodb_table_create. The key's own policy, not this module, must grant DynamoDB permission to use it (see AWS's 'Key policy for a customer managed key' guidance); DynamoDB uses grants for ongoing access, so the ECS task role itself needs no KMS permission for table reads and writes. Default to none, which keeps the table on the AWS owned key: always-on encryption that needs no key policy of its own."
  type        = string
  default     = null
}

variable "aws_dynamodb_region" {
  description = "AWS region holding the DynamoDB table specified in aws_dynamodb_table, or created by aws_dynamodb_table_create. A DynamoDB table is a regional resource, so this setting has no failover, unlike aws_polly_region and similar settings. Default to the region this module is deployed in."
  type        = string
  default     = null
}

variable "timezone" {
  description = "Timezone for request date & time (IANA timezone identifier). Default to UTC."
  type        = string
  default     = null
}

variable "openai_routes_prefix" {
  description = "OpenAI API compatible routes prefix."
  type        = string
  default     = null
}

variable "anthropic_routes_prefix" {
  description = "Anthropic API compatible routes prefix. Default to '/anthropic'."
  type        = string
  default     = null
}

variable "cohere_routes_prefix" {
  description = "Cohere API compatible routes prefix. Default to '/cohere'."
  type        = string
  default     = null
}

variable "aws_bedrock_allow_guardrail_override" {
  description = "Allow users to override the global guardrail configuration at request level using headers (X-Amzn-Bedrock-GuardrailIdentifier, X-Amzn-Bedrock-GuardrailVersion, X-Amzn-Bedrock-Trace). When disabled and a global guardrail is configured, request headers are ignored for security. Defaults to false for security."
  type        = bool
  default     = null
}

variable "aws_bedrock_allow_service_tier_override" {
  description = "Allow users to select the service tier at request level, through the 'service_tier' request parameter or the X-Amzn-Bedrock-Service-Tier header. When disabled, a request cannot change the tier configured for the model by default_model_service_tiers or by the model alias it names. A model with no configured tier still honors the request in either case. Defaults to true."
  type        = bool
  default     = null
}

variable "anthropic_beta_filter" {
  description = "Enable filtering of unsupported anthropic_beta flags for Anthropic Claude models. When enabled, flags not in the allowlist are silently removed to prevent Bedrock ValidationException errors. Default to true."
  type        = bool
  default     = null
}

variable "anthropic_beta_allowlist" {
  description = "Additional anthropic_beta flags to allow beyond the built-in defaults. Comma-separated string. Merged with the built-in set of Bedrock-supported flags. Only effective when anthropic_beta_filter is true."
  type        = string
  default     = null
}

variable "api_key_create" {
  description = "If true, generate and return an API key using the 'api_key' output. When specified, all API requests must include this key. Mutually exclusive with api_key, api_key_ssm_parameter, and api_key_secretsmanager_secret."
  type        = bool
  default     = false
}

variable "api_key" {
  description = "API key for client authentication. When specified, all API requests must include this key. Mutually exclusive with api_key_create, api_key_ssm_parameter, and api_key_secretsmanager_secret."
  type        = string
  sensitive   = true
  default     = null
}

variable "api_key_ssm_parameter" {
  description = "AWS Systems Manager Parameter Store parameter name containing the API key. Mutually exclusive with api_key_create, api_key, and api_key_secretsmanager_secret. When using this option, you must create an IAM policy granting ssm:GetParameter permission and pass the policy ARN to var.ecs_task_role_policy_arns."
  type        = string
  default     = null
}

variable "api_key_secretsmanager_secret" {
  description = "AWS Secrets Manager secret name containing the API key. Mutually exclusive with api_key_create, api_key, and api_key_ssm_parameter. When using this option, you must create an IAM policy granting secretsmanager:GetSecretValue permission and pass the policy ARN to var.ecs_task_role_policy_arns."
  type        = string
  default     = null
}

variable "api_key_secretsmanager_key" {
  description = "Key name within the AWS Secrets Manager secret containing the API key. Only used when api_key_secretsmanager_secret is specified."
  type        = string
  default     = null
}

variable "oauth_resource_identifier" {
  description = "Public URL clients use to reach the API, for example 'https://api.example.com', which is normally 'https://' followed by alb_domain_name. Setting it publishes an OAuth 2.0 protected resource metadata document at '/.well-known/oauth-protected-resource' and puts that address in the challenge every 401 response carries, so an AI agent can discover where to obtain a token. Must be the exact origin clients dial: scheme and host, no path, no trailing slash. Requires either aws_cognito_user_pool_id, whose issuer is then published, or an explicit oauth_authorization_servers. If not specified, nothing is published."
  type        = string
  default     = null
}

variable "oauth_authorization_servers" {
  description = "Issuer URLs of the OAuth 2.0 authorization servers that issue tokens for the API, as a comma-separated list, published in the protected resource metadata. Leave it unset when aws_cognito_user_pool_id is specified: the pool's own issuer is published, resolved for the partition the pool lives in. Setting it explicitly is for a deployment that accepts tokens from another authorization server, and the list must still name the configured pool's issuer. Required only when no user pool is configured and oauth_resource_identifier is."
  type        = string
  default     = null
}

variable "oauth_scopes_supported" {
  description = "OAuth 2.0 scopes a token needs to call the API, as a comma-separated list, advertised in the protected resource metadata and in the 401 challenge. Requires oauth_resource_identifier. If not specified, aws_cognito_required_scopes is advertised, so the scopes a token needs are declared in one place."
  type        = string
  default     = null
}

variable "authentication_mode" {
  description = "Which client authentication methods this deployment accepts: 'any' for every method that is configured, 'api_key' for the API key only, or 'cognito' for Amazon Cognito user pool tokens only. The value asserts the intended security posture: the server fails to start when the selected method is not configured, and when a method that would be ignored is configured anyway, so a credential is never accepted or silently refused by accident. Default to 'any'."
  type        = string
  default     = null

  validation {
    condition     = var.authentication_mode == null || contains(["any", "api_key", "cognito"], coalesce(var.authentication_mode, "any"))
    error_message = "Must be one of 'any', 'api_key' or 'cognito'."
  }
}

variable "aws_cognito_user_pool_id" {
  description = "Identifier of the Amazon Cognito user pool whose tokens authenticate clients, for example 'eu-west-3_a1b2c3d4e'. Clients send a pool access token in the 'Authorization: Bearer <token>' header; its signature, issuer, expiry, application and scopes are validated on every request. The identifier is prefixed by the pool's AWS Region, which is where the signing keys are read from. Requires aws_cognito_client_ids. Default to none (user pool authentication disabled)."
  type        = string
  default     = null

  validation {
    condition     = var.aws_cognito_user_pool_id == null || can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]_[A-Za-z0-9]+$", var.aws_cognito_user_pool_id))
    error_message = "Must be a Cognito user pool ID, <region>_<suffix>."
  }
}

variable "aws_cognito_client_ids" {
  description = "Amazon Cognito user pool application client IDs whose tokens are accepted, as a comma-separated list. A token issued to any other application is rejected. Required when aws_cognito_user_pool_id is specified."
  type        = string
  default     = null
}

variable "aws_cognito_required_scopes" {
  description = "OAuth 2.0 scopes a token must all carry to be accepted, as a comma-separated list. Custom scopes exist only on tokens obtained from the user pool's OAuth 2.0 token endpoint, which requires a resource server and a pool domain; tokens obtained by signing in with a username and password carry only 'aws.cognito.signin.user.admin', so requiring a custom scope rejects them. Default to none (any scope set is accepted)."
  type        = string
  default     = null
}

variable "aws_cognito_accept_id_token" {
  description = "If true, accept Amazon Cognito identity tokens in addition to access tokens. Identity tokens describe the signed-in user rather than granting API access, and carry no scopes; enable only for clients that cannot obtain an access token. Default to false."
  type        = bool
  default     = null
}

variable "aws_cognito_issuer_type" {
  description = "Issuer configuration of the Amazon Cognito user pool, which decides the issuer URL its tokens carry: 'original' for 'https://cognito-idp.<region>.amazonaws.com/<pool-id>', or 'updated' for 'https://issuer-cognito-idp.<region>.amazonaws.com/<pool-id>', available on the Essentials and Plus pool tiers. Tokens whose issuer does not match are rejected, so this must match the pool's own setting. Default to 'original'."
  type        = string
  default     = null

  validation {
    condition     = var.aws_cognito_issuer_type == null || contains(["original", "updated"], coalesce(var.aws_cognito_issuer_type, "original"))
    error_message = "Must be either 'original' or 'updated'."
  }
}

variable "ecs_task_role_policy_arns" {
  description = "List of IAM policy ARNs to attach to the ECS task role. Use this to grant additional permissions to the ECS task, such as access to SSM parameters or Secrets Manager secrets specified in api_key_ssm_parameter or api_key_secretsmanager_secret."
  type        = list(string)
  default     = []
}

variable "otel_enabled" {
  description = "Enable OpenTelemetry distributed tracing. Default to false."
  type        = bool
  default     = null
}

variable "otel_service_name" {
  description = "Service name identifier for OpenTelemetry traces. Default to 'stdapi.ai'."
  type        = string
  default     = null
}

variable "otel_exporter_endpoint" {
  description = "OpenTelemetry traces export endpoint URL."
  type        = string
  default     = null
}

variable "otel_sample_rate" {
  description = "OpenTelemetry trace sampling rate (0.0 to 1.0)."
  type        = number
  default     = null
  validation {
    condition     = var.otel_sample_rate == null || (var.otel_sample_rate >= 0.0 && var.otel_sample_rate <= 1.0)
    error_message = "Sample rate must be between 0.0 and 1.0."
  }
}

variable "log_request_params" {
  description = "If True, add requests and responses parameters to logs. Should not be enabled in production. Default to false."
  type        = bool
  default     = null
}

variable "log_client_ip" {
  description = "If True, log the client IP address for each request and add it to OpenTelemetry spans. Default to false."
  type        = bool
  default     = null
}

variable "log_level" {
  description = "Minimum logging level to output: info, warning, error, critical, or disabled. Default to info."
  type        = string
  default     = null
  validation {
    condition     = var.log_level == null || contains(["info", "warning", "error", "critical", "disabled"], var.log_level)
    error_message = "Must be one of: info, warning, error, critical, disabled."
  }
}

variable "strict_input_validation" {
  description = "If True, raise error on extra fields in input request. Default to false."
  type        = bool
  default     = null
}

variable "extra_model_params_drop_all" {
  description = "If true, disable the 'extra model parameters' passthrough entirely: no undeclared request field is ever forwarded to Amazon Bedrock as a provider-specific inference parameter, on any route that supports it. Overrides extra_model_params_denylist, which no longer matters once nothing is forwarded. Default to false, which keeps the passthrough, filtered by the built-in default denylist and extra_model_params_denylist."
  type        = bool
  default     = null
}

variable "extra_model_params_denylist" {
  description = "Additional parameter names to strip from the 'extra model parameters' passthrough, as a comma-separated list. Merged with the built-in default denylist of client-control parameters (such as 'drop_params', 'api_key' or 'custom_llm_provider') that some OpenAI-SDK-based clients leak into extra_body and that are never legitimate Bedrock model parameters. Only effective when extra_model_params_drop_all is false. Default to the built-in denylist alone. Example: 'x_internal_debug_flag,x_proxy_trace_id'"
  type        = string
  default     = null
}

variable "default_model_params" {
  description = "Default inference parameters applied to specific models automatically. JSON string format."
  type        = string
  default     = null
}

variable "default_model_service_tiers" {
  description = "Default service tier applied to specific models automatically when no explicit tier is provided (default, flex, priority, reserved). JSON string format, e.g. {\"amazon.nova-pro-v1:0\": \"flex\"}."
  type        = string
  default     = null
}

variable "default_tts_model" {
  description = "Default text-to-speech model to use if not specified in the request. Default to 'amazon.polly-standard'."
  type        = string
  default     = null
  validation {
    condition     = var.default_tts_model == null || contains(["amazon.polly-standard", "amazon.polly-neural", "amazon.polly-long-form", "amazon.polly-generative"], var.default_tts_model)
    error_message = "Must be one of: amazon.polly-standard, amazon.polly-neural, amazon.polly-long-form, amazon.polly-generative."
  }
}

variable "default_tts_language" {
  description = "Default text-to-speech language to use if not specified in the request. Default to language autodetection."
  type        = string
  default     = null
}

variable "drop_unsupported_system_prompt" {
  description = "If true, system prompts are silently dropped when models don't support them. If false, an error is returned when a system prompt is passed to a model that doesn't support system prompts (e.g., mistral.mistral-7b models). Default: true for backward compatibility."
  type        = bool
  default     = null
}

variable "tokens_estimation" {
  description = "Deprecated and ignored since stdapi.ai v1.14.0: token estimation has been removed; only real AWS-billed usage is reported."
  type        = bool
  default     = null
}

variable "tokens_estimation_default_encoding" {
  description = "Deprecated and ignored since stdapi.ai v1.14.0: token estimation has been removed."
  type        = string
  default     = null
}

variable "aws_bedrock_session_encryption_key_arn" {
  description = "KMS key ARN encrypting the AWS Bedrock sessions that back stored responses and chat completions (store=true). Default to the AWS-managed key."
  type        = string
  default     = null
}

variable "cloudwatch_metrics" {
  description = "If True, emit per-request AWS-billed usage as CloudWatch Embedded Metric Format (EMF) log lines. Default to false."
  type        = bool
  default     = null
}

variable "cloudwatch_metrics_namespace" {
  description = "CloudWatch namespace for the emitted usage metrics. Default to 'stdapi'."
  type        = string
  default     = null
}

variable "cost_tracking" {
  description = "Enable per-request cost estimation from AWS Price List values (adds the pricing:GetProducts permission). Reported costs are an estimate from published prices, not your actual AWS bill; use cost_price_overrides for models the Price List API does not cover. Default to false."
  type        = bool
  default     = null
}

variable "cost_price_overrides" {
  description = "Unit price overrides for models not covered by the AWS Price List API, as a map of model IDs to dimension-name/price maps."
  type        = map(map(number))
  default     = null
}

variable "enable_docs" {
  description = "Enable interactive API documentation UI at /docs. Default to false."
  type        = bool
  default     = null
}

variable "enable_redoc" {
  description = "Enable ReDoc API documentation UI at /redoc. Default to false."
  type        = bool
  default     = null
}

variable "enable_openapi_json" {
  description = "Enable OpenAPI JSON schema endpoint at /openapi.json. Default to false."
  type        = bool
  default     = null
}

variable "enable_mcp_streamable_http" {
  description = "Enable the MCP (Model Context Protocol) server using Streamable HTTP transport. When enabled, exposes an MCP-compatible endpoint at /mcp. This is the recommended MCP transport. Default to false."
  type        = bool
  default     = null
}

variable "mcp_stateless_http" {
  description = "Serve the MCP Streamable HTTP transport in stateless mode. Each request is then handled by a fresh transport that keeps no session state, so any client may call /mcp without initializing a session first and any task may serve any request. Required by hosts that provide their own session isolation and inject an 'Mcp-Session-Id' header the server never issued. Requires enable_mcp_streamable_http. Default to false."
  type        = bool
  default     = null
}

variable "enable_mcp_sse" {
  description = "Enable the MCP (Model Context Protocol) server using Server-Sent Events (SSE) transport. When enabled, exposes MCP endpoints at /sse. Maintained for backwards compatibility with older MCP clients; prefer enable_mcp_streamable_http for new deployments. Default to false."
  type        = bool
  default     = null
}

variable "mcp_include_tools" {
  description = "Comma-separated list of MCP tool names to expose exclusively. Only the listed tools will be available to MCP clients; all others are hidden. When both mcp_include_tools and mcp_exclude_tools are specified, mcp_exclude_tools values are removed from mcp_include_tools. Example: 'openai_chat_completion,openai_embedding,openai_model_list'"
  type        = string
  default     = null
}

variable "mcp_exclude_tools" {
  description = "Comma-separated list of MCP tool names to hide from MCP clients. All other tools remain exposed. When mcp_include_tools is also specified, these values are removed from it. Example: 'openai_files_delete,anthropic_files_delete'"
  type        = string
  default     = null
}

variable "cors_allow_origins" {
  description = "List of origins allowed to make cross-origin requests (CORS). Use ['*'] to allow all origins. Default to no CORS headers."
  type        = list(string)
  default     = null
}

variable "trusted_hosts" {
  description = "List of trusted host header values for Host header validation. Supports wildcard subdomains. Disabled by default."
  type        = list(string)
  default     = null
}

variable "proxy_trusted_hosts" {
  description = "Trusted proxy hosts/IPs (CIDRs) whose X-Forwarded-* headers are honored when proxy headers are enabled. Restrict to your reverse proxy's IP range so direct clients cannot forge their source IP. Write entries in their natural address family: on an IPv6-enabled VPC the server binds a dual-stack socket and sees IPv4 peers in IPv4-mapped form, and the module adds the matching '::ffff:' range for every IPv4 entry automatically. When null and proxy headers are auto-enabled (var.alb_enabled and var.log_client_ip both true), defaults to the ALB subnet CIDRs so only the ALB is trusted; otherwise the server default ('*') applies."
  type        = list(string)
  default     = null
}

variable "max_input_file_size" {
  description = "Maximum size in bytes of an inline input file loaded into memory (base64, data URI, or a downloaded HTTP(S)/S3 source). Requests exceeding it are rejected with HTTP 413 before the content is fully decoded. Default to 0 (no limit)."
  type        = number
  default     = null
}

variable "max_concurrent_input_downloads" {
  description = "Maximum number of input files fetched or resolved concurrently within a single request, bounding outbound downloads against socket/memory exhaustion and SSRF amplification. Default to 8."
  type        = number
  default     = null
}

variable "enable_proxy_headers" {
  description = "Enable ProxyHeadersMiddleware to trust X-Forwarded-* headers from reverse proxies. Automatically enabled when var.alb_enabled is true and var.log_client_ip is true."
  type        = bool
  default     = null
}

variable "enable_gzip" {
  description = "Enable GZip compression middleware for HTTP responses. Disabled by default."
  type        = bool
  default     = null
}

variable "ssrf_protection_block_private_networks" {
  description = "Enable SSRF protection by blocking requests to private/local networks. When enabled, the server will reject requests to RFC 1918 private addresses (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16), loopback, link-local, reserved, and multicast addresses. Default to true."
  type        = bool
  default     = null
}

variable "ai_response_timeout" {
  description = "Maximum time in seconds to wait for an AI model to complete a response. Applies to both streaming and non-streaming requests. The default of 600 seconds accommodates models with extended reasoning. Increase for long-running requests (e.g., large document analysis); decrease to fail fast on unexpectedly slow responses. Default to 600."
  type        = number
  default     = null
}

variable "shutdown_drain_timeout" {
  description = "Maximum time in seconds the server waits, once asked to stop, for background work that requests started and did not wait for: temporary file cleanups, vector store file indexing, and the release of live audio sessions. Work still running when the wait ends is cancelled and counted as a warning in the server's stop log event. This wait is best effort, not a delivery guarantee: a container runtime sends SIGKILL a fixed delay after the stop signal. This module raises the task's own stop timeout to match, so the wait is not cut short here; a deployment that does not use this module must raise it itself, because the default on Amazon ECS is 30 seconds. Values above 110 are capped, since Fargate accepts at most 120. Set to 0 to stop as fast as possible, cancelling background work immediately. Default to 10."
  type        = number
  default     = null

  validation {
    condition     = var.shutdown_drain_timeout == null || var.shutdown_drain_timeout >= 0
    error_message = "Must be greater than or equal to 0."
  }
}

variable "model_cache_seconds" {
  description = "Cache lifetime in seconds for the Bedrock models list."
  type        = number
  default     = null
}

variable "model_aliases" {
  description = <<-EOT
    Map of model aliases to actual model IDs.
    Allows users to reference models using custom alias names.
    This is merged with default system aliases at startup.
    User-provided aliases take precedence over system defaults.

    An alias maps either to a model ID, or to an object carrying that model plus
    the configuration to apply to requests naming the alias: "service_tier",
    "guardrail_id" with "guardrail_version" (and optionally "guardrail_trace"),
    "metadata" and "extra_params". Those values override the equivalent
    server-wide configuration, and a value sent with the request still wins
    unless its override variable (aws_bedrock_allow_guardrail_override,
    aws_bedrock_allow_service_tier_override) is disabled.

    Example: {
      "my-tts": "amazon.polly-neural",
      "my-stt": "amazon.transcribe",
      "my-chat": {
        "model": "amazon.nova-lite-v1:0",
        "service_tier": "flex",
        "metadata": { "team": "research" },
        "extra_params": { "temperature": 0.2 }
      }
    }
  EOT
  type        = any
  default     = null
}

variable "image_generation_model" {
  description = "Default model ID for image generation (e.g. 'amazon.nova-canvas-v1:0'). Required unless the client or the LLM specifies a model per call."
  type        = string
  default     = null
}

variable "realtime_client_secret_key" {
  description = <<-EOT
    Secret the ephemeral client secrets of the Realtime API are signed with. Any value works as long as every task of the deployment shares it: a secret minted by one task is verified by whichever one the client's WebSocket reaches. Passed to the container as an ECS secret stored in AWS Systems Manager Parameter Store, never as a plain environment variable.

    When not specified, the server derives the key from the configured API key. When no API key is configured either (api_key, api_key_create, api_key_ssm_parameter and api_key_secretsmanager_secret all unset), the module generates a key and stores it the same way, because the server would otherwise fall back to a per-process random value, under which a client secret minted by one task is rejected by every other task and by any task replacing it after a deployment.
  EOT
  type        = string
  sensitive   = true
  default     = null
}

variable "realtime_allow_session_override" {
  description = "Allow a client connecting to the Realtime API with an ephemeral client secret to override the session configuration that secret carries. When disabled, the model, the instructions and the output token cap minted into the secret are final: a 'model' query parameter naming another model is refused, and a session.update changing one of them answers an error. Default to true, which is the upstream behavior; disable it in a multi-tenant deployment where the secret is the only thing constraining an untrusted client."
  type        = bool
  default     = null
}

variable "version_to_deploy" {
  description = "Container image version tag from AWS Marketplace. Leave unset to automatically use the latest stable version. Only override for testing or rollback purposes. A '-arm64' or '-amd64' suffix is appended automatically based on var.cpu_architecture, so the value must not include an architecture suffix."
  type        = string
  default     = "1.16.1"
}

# KMS configuration

variable "kms_key_id" {
  description = "If specified, directly use this KMS key instead of creating a dedicated one for the application."
  type        = string
  default     = null
}

# VPC configuration

variable "vpc_endpoints_allowed" {
  description = "If true, VPC endpoints interfaces are privileged to give AWS services access to the application if no internet access is required. VPC endpoint Gateway are always provisioned. Disable only if cost is privileged over security."
  type        = bool
  default     = true
}

variable "nat_gateways_allowed" {
  description = "If true, NAT gateways are used to give internet access to the application. If Disabled and internet access is required, application subnets will be public. Disable only if cost is privileged over security. "
  type        = bool
  default     = true
}

variable "availability_zones_count" {
  description = "Maximum count of availability zones to provision with the dedicated VPC. Default to all available availability zones."
  type        = number
  default     = null
}

variable "subnet_ids" {
  description = "If specified, directly use theses subnets instead of creating a dedicated VPC."
  type        = list(string)
  default     = []
}

variable "security_group_id" {
  description = "If specified and 'subnet_ids' is specified, use this security group instead of creating a new one giving access to internet and AWS services."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_flow_log_enabled" {
  description = "If true, enable VPC flow log. Disable only if cost is privileged over security."
  type        = bool
  default     = true
}

variable "compliance_vpc_endpoints_enabled" {
  description = "If true, add the interface VPC endpoints for ECR API, ECR Docker Registry, Systems Manager, SSM Incident Manager Contacts and SSM Incident Manager. Enable only if you have high compliance requirements — each interface endpoint adds cost. Security Hub: EC2.55/EC2.56/EC2.57/EC2.58/EC2.60 — default false = fail; set to true to pass."
  type        = bool
  default     = false
}

variable "guardduty_vpc_endpoint_enabled" {
  description = "If true, add the interface VPC endpoint required by GuardDuty Runtime Monitoring. Only relevant if you use GuardDuty Runtime Monitoring on resources in this VPC — leave false otherwise. Recommended whenever Runtime Monitoring is enabled, even with GuardDuty's automated agent configuration, since managing it here ensures correct subnet placement. Not mapped to a Security Hub control; default false = endpoint not created."
  type        = bool
  default     = false
}

variable "dns_firewall_enabled" {
  description = "If true, create a Route 53 Resolver DNS Firewall rule group and associate it with the dedicated VPC, blocking/alerting on DNS queries per var.dns_firewall_managed_domain_list_ids and var.dns_firewall_advanced_enabled. Helps mitigate malicious-URL injection via user-supplied URL/file references (images, documents, audio) by blocking outbound DNS resolution to known-malicious domains, in addition to the application's own SSRF protection. Only supported for the dedicated VPC this module creates; cannot be enabled when using external subnets (var.subnet_ids). Not mapped to a Security Hub control; default false = feature not created."
  type        = bool
  default     = false
}

variable "dns_firewall_managed_domain_list_ids" {
  description = "Map of AWS Managed Domain List name to ID (e.g. { \"AWSManagedDomainsAggregateThreatList\" = \"rslvr-fdl-...\" }) to block/alert on via var.dns_firewall_action. Defaults (null) to the Aggregate Threat List ID built into the underlying VPC module for the current region, covering commercial regions enabled by default — no AWS CLI call or extra permissions required. For a region not covered by that default, look up the ID with 'aws route53resolver list-firewall-domain-lists' and pass it explicitly. Ignored if var.dns_firewall_enabled is false. Set to {} to skip managed-list rules while still using var.dns_firewall_advanced_enabled."
  type        = map(string)
  default     = null
}

variable "dns_firewall_action" {
  description = "Action taken by DNS Firewall when a query matches a domain from var.dns_firewall_managed_domain_list_ids, and (if var.dns_firewall_advanced_enabled) a DNS Firewall Advanced threat detection. Valid values: 'ALLOW', 'BLOCK', 'ALERT'. 'ALLOW' isn't valid for DNS Firewall Advanced rules, so it's treated as 'BLOCK' for those only. Ignored if var.dns_firewall_enabled is false."
  type        = string
  default     = "BLOCK"
  validation {
    condition     = contains(["ALLOW", "BLOCK", "ALERT"], var.dns_firewall_action)
    error_message = "dns_firewall_action must be one of: ALLOW, BLOCK, ALERT."
  }
}

variable "dns_firewall_advanced_enabled" {
  description = "If true, add Route 53 Resolver DNS Firewall Advanced rules (additional cost) blocking DNS queries identified as domain generation algorithm (DGA) or DNS tunneling activity, on top of any managed-domain-list rules. Ignored if var.dns_firewall_enabled is false."
  type        = bool
  default     = false
}

variable "dns_firewall_advanced_confidence_threshold" {
  description = "Confidence threshold for DNS Firewall Advanced rules. Valid values: 'LOW', 'MEDIUM', 'HIGH'. Lower thresholds catch more threats at the cost of more false positives. Ignored if var.dns_firewall_advanced_enabled is false."
  type        = string
  default     = "HIGH"
  validation {
    condition     = contains(["LOW", "MEDIUM", "HIGH"], var.dns_firewall_advanced_confidence_threshold)
    error_message = "dns_firewall_advanced_confidence_threshold must be one of: LOW, MEDIUM, HIGH."
  }
}

variable "dns_firewall_priority" {
  description = "Processing priority for the DNS Firewall rule group association within the VPC (lower is processed first). Must be unique among all rule group associations on the same VPC, including ones created outside this module. Ignored if var.dns_firewall_enabled is false."
  type        = number
  default     = 101
}

# ECS Container Configuration

variable "cpu" {
  description = "ECS task CPU count. Valid values: 0.25, 0.5, 1, 2, 4, 8 & 16. Default of 0.25 vCPU is suitable for common use cases (text generation, embeddings). Increase for intensive workloads (multimodal requests, large LLM models)."
  type        = number
  default     = 0.25
}

variable "memory" {
  description = "ECS task memory (MiB). Valid values depends on the var.container_cpu value (x1024), see the ECS documentation for more information. Default of 512 MiB is suitable for common use cases (text generation, embeddings). Increase for intensive workloads (multimodal requests, large LLM models)."
  type        = number
  default     = 512
}

variable "cpu_architecture" {
  description = "CPU architecture. Valid values: 'X86_64' or 'ARM64'."
  type        = string
  default     = "ARM64"
}

# ECS Service Configuration

variable "service_discovery_dns_namespace_id" {
  description = "If specified, enable Service discovery on the ECS service and attach it to this Cloud Map namespace."
  type        = string
  default     = null
}

variable "service_discovery_dns_name" {
  description = "DNS name for service discovery. By default, uses the service name. Only if service_discovery_dns_namespace_id is specified."
  type        = string
  default     = null
}

# ECS Auto-Scaling Configuration

variable "autoscaling_min_capacity" {
  description = "Minimum number of ECS tasks. If not specified, defaults to the number of availability zones."
  type        = number
  default     = null
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of ECS tasks for auto-scaling. If null, uses AWS default."
  type        = number
  default     = null
}

variable "autoscaling_cpu_target_percent" {
  description = "Target CPU utilization percentage for auto-scaling. If null, uses AWS default."
  type        = number
  default     = null
}

variable "autoscaling_memory_target_percent" {
  description = "Target memory utilization percentage for auto-scaling. If null, memory-based scaling is disabled."
  type        = number
  default     = null
}

variable "autoscaling_alb_target_requests_per_target" {
  description = "Target number of ALB requests per ECS task for auto-scaling. If null or ALB not enabled, request-based scaling is disabled."
  type        = number
  default     = null
}

variable "autoscaling_scale_in_cooldown" {
  description = "Time in seconds after a scale-in activity completes before another scale-in can start. If null, uses AWS default."
  type        = number
  default     = null
}

variable "autoscaling_scale_out_cooldown" {
  description = "Time in seconds after a scale-out activity completes before another scale-out can start. If null, uses AWS default."
  type        = number
  default     = null
}

variable "autoscaling_schedule_stop" {
  description = "Schedule to stop/pause the service (scale to 0). Format: cron(fields) or at(yyyy-mm-ddThh:mm:ss) in UTC."
  type        = string
  default     = null
}

variable "autoscaling_schedule_start" {
  description = "Schedule to start the service if stopped. Format: cron(fields) or at(yyyy-mm-ddThh:mm:ss) in UTC."
  type        = string
  default     = null
}

variable "autoscaling_spot_percent" {
  description = "Percent of capacity over the minimum capacity to run with Fargate Spot (~70% cost discount). Set to 100 to use only Spot instances. Set to 0 to disable Spot instances."
  type        = number
  default     = 0
  validation {
    condition     = var.autoscaling_spot_percent >= 0 && var.autoscaling_spot_percent <= 100
    error_message = "autoscaling_spot_percent must be between 0 and 100."
  }
}

variable "autoscaling_spot_on_demand_min_capacity" {
  description = "Minimum number of on-demand tasks when autoscaling_spot_percent is enabled. If not specified, defaults to autoscaling_min_capacity."
  type        = number
  default     = null
}

# Application Load Balancer Configuration

variable "alb_enabled" {
  description = "If true, create an Application Load Balancer for the ECS service. Cannot be used with external subnets (subnet_ids)."
  type        = bool
  default     = false
  validation {
    condition     = !var.alb_enabled || length(var.subnet_ids) == 0
    error_message = "alb_enabled cannot be enabled when using external subnets (subnet_ids). ALB requires a dedicated VPC with public subnets managed by this module."
  }
}

variable "alb_public" {
  description = "If true, create a public (internet-facing) ALB with dedicated public subnets. If false, create a private (internal) ALB using app subnets."
  type        = bool
  default     = false
}

variable "alb_ingress_ipv4_cidrs" {
  description = "List of IPv4 CIDR blocks allowed to access the ALB. Default to ['0.0.0.0/0'] for public access."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_ingress_ipv6_cidrs" {
  description = "List of IPv6 CIDR blocks allowed to access the ALB. Default to ['::/0'] for public access."
  type        = list(string)
  default     = ["::/0"]
}

variable "alb_idle_timeout" {
  description = "The time in seconds that the connection is allowed to be idle. Range: 1-4000 seconds. Default to 3600 (1 hour) to support slow LLM responses and long-running operations like AWS Transcribe."
  type        = number
  default     = 3600
  validation {
    condition     = var.alb_idle_timeout >= 1 && var.alb_idle_timeout <= 4000
    error_message = "alb_idle_timeout must be between 1 and 4000 seconds."
  }
}

variable "alb_route53_zone_id" {
  description = "Route 53 hosted zone ID for DNS records. If not specified, automatically infers the zone from the parent domain of domain_name (e.g., 'api.example.com' → 'example.com', 'api.sandbox.example.com' → 'sandbox.example.com')."
  type        = string
  default     = null
}

variable "alb_route53_zone_name" {
  description = "Route 53 hosted zone name for DNS records (e.g., 'example.com'). Alternative to route53_zone_id - module will look up the zone ID automatically. If specified with domain_name, creates DNS records and ACM certificate."
  type        = string
  default     = null
}

variable "alb_domain_name" {
  description = "Primary domain name for the application (e.g., api.example.com). Creates Route 53 A record and ACM certificate. If route53_zone_id is not specified, automatically looks up the most specific parent domain zone."
  type        = string
  default     = null
}

variable "alb_route53_zone_private" {
  description = "If true, the Route 53 zone is private. If false, it's public. Used when looking up the zone by name."
  type        = bool
  default     = false
}

variable "alb_certificate_create" {
  description = "If true, create an ACM certificate and validate it via DNS. Only used when certificate_arn is not specified. Requires route53_zone_id, domain_name, and route53_zone_private=false."
  type        = bool
  default     = true
}

variable "alb_certificate_arn" {
  description = "Existing ACM certificate ARN to attach to the HTTPS listener. When specified, takes precedence over certificate_create. If not specified and certificate_create is true, a certificate will be created automatically."
  type        = string
  default     = null
}

# ALB WAF Configuration

variable "alb_waf_enabled" {
  description = "If true, create a WAF WebACL and associate it with the ALB (requires alb_enabled=true)."
  type        = bool
  default     = false
  validation {
    condition     = !var.alb_waf_enabled || var.alb_enabled
    error_message = "waf_enabled requires alb_enabled to be true. WAF can only be associated with an Application Load Balancer."
  }
}

variable "alb_waf_rate_limit" {
  description = "Maximum number of requests allowed from a single IP address in a 5-minute period. If null, rate limiting is disabled."
  type        = number
  default     = null
}

variable "alb_waf_block_anonymous_ips" {
  description = "If true, block requests from anonymous IP addresses (VPNs, proxies, Tor exit nodes)."
  type        = bool
  default     = false
}

variable "alb_waf_logging_enabled" {
  description = "If true, enable WAF logging to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "alb_access_logging_enabled" {
  description = "If true, enable ALB access logging to a dedicated S3 bucket. Security Hub: ELB.5 (Application Load Balancers should have logging enabled) — default true = pass; only relevant when var.alb_enabled is true."
  type        = bool
  default     = true
}

variable "alb_ssl_policy" {
  description = "SSL/TLS security policy for the ALB HTTPS listener. Defaults to the AWS-recommended post-quantum policy. See https://docs.aws.amazon.com/elasticloadbalancing/latest/application/describe-ssl-policies.html"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
}

# Logging and Monitoring

variable "cloudwatch_logs_retention_in_days" {
  description = "Cloudwatch logs retention in days. Applies to every log group this module and its child modules create, including the Container Insights performance log group. Security Hub: CloudWatch.16 (CloudWatch log groups should be retained for a specified time period) requires at least 365 days by default — default 365 = pass; lowering it fails this control."
  type        = number
  default     = 365
}

variable "container_insight" {
  description = "Container insight configuration. Valid values: 'enhanced', 'enabled', 'disabled'. Default to 'enabled'. Security Hub: ECS.12 (ECS clusters should use Container Insights) — default 'enabled' = pass; setting 'disabled' fails this control."
  type        = string
  default     = "enabled"
  validation {
    condition     = contains(["enhanced", "enabled", "disabled"], var.container_insight)
    error_message = "var.container_insight must be 'enhanced', 'enabled', or 'disabled'."
  }
}

variable "alarms_enabled" {
  description = "Enable CloudWatch alarms. This should be set to true if sns_topic_arn is provided."
  type        = bool
  default     = false
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms. If specified, CloudWatch alarms will be created for high memory usage and unhealthy containers."
  type        = string
  default     = null
}

# Other

variable "deletion_protection" {
  description = "If true, enable deletion protection on eligible resources."
  type        = bool
  default     = false
}

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

variable "aws_s3_bucket" {
  description = "Existing S3 bucket name for storing generated files and application data. When specified, takes precedence over aws_s3_bucket_create. If not specified and aws_s3_bucket_create is true, a bucket will be created automatically."
  type        = string
  default     = null
}

variable "aws_s3_regional_buckets" {
  description = <<-EOT
    Region-specific S3 buckets for temporary file storage during Bedrock operations.
    Keys are AWS region identifiers, values are bucket names.

    Example: { "us-east-1" = "my-bucket-us-east-1", "us-west-2" = "my-bucket-us-west-2" }

    Required for Bedrock operations with multimodal input or document processing.
    Use the companion module 'stdapi-ai/stdapi-ai-s3-regional-bucket' to create these buckets automatically.
    See: https://github.com/stdapi-ai/terraform-aws-stdapi-ai-s3-regional-bucket
  EOT
  type        = map(string)
  default     = null
}

variable "aws_s3_buckets_kms_keys_arns" {
  description = "List of KMS key ARNs used to encrypt the regional S3 buckets. Required to grant the server permissions to access encrypted regional buckets."
  type        = list(string)
  default     = []
}

variable "aws_s3_accelerate" {
  description = "Enable S3 Transfer Acceleration for presigned URLs. Default to false."
  type        = bool
  default     = null
}

variable "aws_polly_region" {
  description = "AWS region for Polly text-to-speech service. Default to first var.aws_bedrock_regions region or the current region."
  type        = string
  default     = null
}

variable "aws_comprehend_region" {
  description = "AWS region for Comprehend language detection service. Default to first var.aws_bedrock_regions region or the current region."
  type        = string
  default     = null
}

variable "aws_bedrock_regions" {
  description = "List of AWS regions where Bedrock AI models are available. Default to the current region."
  type        = list(string)
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
  description = "If true, allow legacy Bedrock models to be used. Default to true."
  type        = bool
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
  description = "AWS region for Transcribe speech-to-text service. Default to first var.aws_bedrock_regions region or the current region."
  type        = string
  default     = null
}

variable "aws_transcribe_s3_bucket" {
  description = "AWS S3 bucket name for temporary file storage during transcription. Defaults to aws_s3_bucket if not specified."
  type        = string
  default     = null
}

variable "aws_s3_tmp_prefix" {
  description = "S3 prefix (folder path) for temporary files used during job processing. Default to 'tmp/'."
  type        = string
  default     = null
}

variable "aws_translate_region" {
  description = "AWS region for Translate text translation service. Default to first var.aws_bedrock_regions region or the current region."
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

variable "default_model_params" {
  description = "Default inference parameters applied to specific models automatically. JSON string format."
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

variable "tokens_estimation" {
  description = "If True, estimate the number of tokens using a tokenizer when not directly returned by the model. Default to false."
  type        = bool
  default     = null
}

variable "tokens_estimation_default_encoding" {
  description = "Tiktoken Tokenizer encoding to use for token count estimation."
  type        = string
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

variable "model_cache_seconds" {
  description = "Cache lifetime in seconds for the Bedrock models list."
  type        = number
  default     = null
}

variable "version_to_deploy" {
  description = "Container image version tag from AWS Marketplace. Leave unset to automatically use the latest stable version. Only override for testing or rollback purposes."
  type        = string
  default     = "1.0.2"
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
  description = "Route53 hosted zone ID for DNS records. If not specified, automatically infers the zone from the parent domain of domain_name (e.g., 'api.example.com' → 'example.com', 'api.sandbox.example.com' → 'sandbox.example.com')."
  type        = string
  default     = null
}

variable "alb_route53_zone_name" {
  description = "Route53 hosted zone name for DNS records (e.g., 'example.com'). Alternative to route53_zone_id - module will look up the zone ID automatically. If specified with domain_name, creates DNS records and ACM certificate."
  type        = string
  default     = null
}

variable "alb_domain_name" {
  description = "Primary domain name for the application (e.g., api.example.com). Creates Route53 A record and ACM certificate. If route53_zone_id is not specified, automatically looks up the most specific parent domain zone."
  type        = string
  default     = null
}

variable "alb_route53_zone_private" {
  description = "If true, the Route53 zone is private. If false, it's public. Used when looking up the zone by name."
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

# Logging and Monitoring

variable "cloudwatch_logs_retention_in_days" {
  description = "Cloudwatch logs retention in days."
  type        = number
  default     = 365
}

variable "container_insight" {
  description = "Container insight configuration. Valid values: 'enhanced', 'enabled', 'disabled'. Default to 'enhanced'."
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

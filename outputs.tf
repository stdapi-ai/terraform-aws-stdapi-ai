# S3 bucket configuration

output "bucket_id" {
  description = "Configuration S3 bucket ID."
  value       = local.s3_bucket_name
}

output "bucket_arn" {
  description = "Configuration S3 bucket ARN."
  value = local.create_s3_bucket ? aws_s3_bucket.main[0].arn : (
    var.aws_s3_bucket != null ? data.aws_s3_bucket.user_provided[0].arn : null
  )
}

# KMS key configuration

output "kms_policy_documents_json" {
  description = "KMS policy documents to add to the policy of the key specified via var.kms_key_id."
  value       = module.kms_key.policy_documents_json
}

output "kms_key_id" {
  description = "KMS key ID."
  value       = module.kms_key.id
}

output "kms_key_arn" {
  description = "KMS key ARN."
  value       = module.kms_key.arn
}

# Regional S3 bucket compagnon module requirements

output "name_prefix" {
  description = "Name prefix for resources. To pass to compagnon module."
  value       = local.name_prefix
}

output "aws_s3_tmp_prefix" {
  description = "S3 prefix (folder path) for temporary files used during job processing. To pass to compagnon module."
  value       = local.s3_tmp_prefix
}

output "deletion_protection" {
  description = "If true, enable deletion protection on eligible resources. To pass to compagnon module."
  value       = var.deletion_protection
}

output "regional_buckets" {
  description = "Map of region → bucket name (user-provided + auto-created)."
  value       = local.regional_buckets_combined
}

# Vector Stores & Batch API configuration

output "vectors_bucket_name" {
  description = "S3 vector bucket name backing the Vector Stores API, or null when it is disabled."
  value       = local.s3_vectors_bucket_name
}

output "vectors_region" {
  description = "Region holding the S3 vector bucket, or null when the Vector Stores API is disabled."
  value       = local.s3_vectors_bucket_name != null ? local.s3_vectors_region : null
}

output "vector_store_queue_url" {
  description = "URL of the Amazon SQS queue carrying the vector store indexing jobs, or null when durable indexing is disabled."
  value       = local.sqs_vector_store_queue_url
}

output "vector_store_queue_arn" {
  description = "ARN of the Amazon SQS queue carrying the vector store indexing jobs, or null when durable indexing is disabled."
  value       = local.sqs_vector_store_queue_arn
}

output "bedrock_batch_role_arn" {
  description = "ARN of the IAM service role Amazon Bedrock assumes to run batch inference jobs, or null when the Batch API is disabled."
  value       = local.bedrock_batch_role_arn
}

# Per-end-user cost attribution

output "bedrock_user_role_arn" {
  description = "ARN of the IAM role the server assumes once per end user, whether created by this module or supplied through aws_bedrock_user_role_arn, or null when per-end-user cost attribution is disabled. Activate the session tag key named by aws_bedrock_user_role_tag_key as a cost allocation tag of type 'IAM principal' to group Amazon Bedrock costs per end user."
  value       = local.bedrock_user_role_arn
}

# Other outputs that may be required by the user

output "api_key" {
  description = "Returns API key value from var.api_key or var.api_key_create. API key values from var.api_key_ssm_parameter or var.api_key_secretsmanager_secret are not returned."
  value       = var.api_key != null ? var.api_key : (var.api_key_create ? random_password.api_key[0].result : null)
  sensitive   = true
}

output "cloudwatch_log_groups_names" {
  description = "CloudWatch log group names for each container in the server."
  value       = module.server.cloudwatch_log_groups_names
}

output "security_group_id" {
  description = "Security group ID for the ECS server service."
  value       = module.server.security_group_id
}

output "service_discovery_service_name" {
  description = "Service discovery service name for the server (only if service discovery is enabled)."
  value       = module.server.service_discovery_service_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer (only if ALB is enabled)."
  value       = var.alb_enabled ? aws_lb.main[0].arn : null
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (only if ALB is enabled)."
  value       = var.alb_enabled ? aws_lb.main[0].dns_name : null
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer (only if ALB is enabled)."
  value       = var.alb_enabled ? aws_lb.main[0].zone_id : null
}

output "alb_security_group_id" {
  description = "Security group ID of the Application Load Balancer (only if ALB is enabled)."
  value       = var.alb_enabled ? aws_security_group.alb[0].id : null
}

output "alb_waf_web_acl_id" {
  description = "ID of the WAF WebACL (only if WAF is enabled)."
  value       = var.alb_enabled && var.alb_waf_enabled ? aws_wafv2_web_acl.main[0].id : null
}

output "alb_waf_web_acl_arn" {
  description = "ARN of the WAF WebACL (only if WAF is enabled)."
  value       = var.alb_enabled && var.alb_waf_enabled ? aws_wafv2_web_acl.main[0].arn : null
}

output "application_url" {
  description = "Application URL (uses domain name if configured, otherwise ALB DNS name)."
  value = var.alb_enabled ? (
    local.dns_enabled ? "https://${var.alb_domain_name}" : (
      local.certificate_arn != null ? "https://${aws_lb.main[0].dns_name}" : "http://${aws_lb.main[0].dns_name}"
    )
  ) : null
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = module.server.ecs_cluster_name
}

output "service_name" {
  description = "ECS service name."
  value       = module.server.ecs_service_name
}

output "port" {
  description = "Container port exposed by the application."
  value       = local.port
}

output "subnet_ids" {
  description = "Subnets IDs where the ECS service is deployed."
  value       = length(var.subnet_ids) > 1 ? var.subnet_ids : module.vpc.subnets_ids
}
output "tenant_keys" {
  description = "Per tenant of var.tenants: the public key ID and the SSM SecureString parameter the server delivers the minted API key through, within a minute of starting or reconciling. Retrieve it once with 'aws ssm get-parameter --name <ssm_parameter> --with-decryption --query Parameter.Value --output text', hand it to the tenant, then delete the parameter -- the copy it holds is the only one, and it is the only thing between a reader of this deployment's KMS key and a working tenant credential. The SecureString is encrypted with that key, so retrieving it takes kms:Decrypt on it as well as ssm:GetParameter on the path. The key itself never enters Terraform state."
  value = {
    for name in keys(var.tenants) : name => {
      key_id        = random_string.tenant_key_id[name].result
      ssm_parameter = "${local.tenant_key_ssm_parameter_prefix}/${random_string.tenant_key_id[name].result}"
    }
  }
}

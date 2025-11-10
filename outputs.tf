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
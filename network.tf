/*
Provision a dedicated VPC for the projet, or use user provided subnets.
*/

locals {
  # Use Bedrock regions list directly
  bedrock_regions = var.aws_bedrock_regions != null ? var.aws_bedrock_regions : []

  # Default region for all services is the first Bedrock region, or current region if Bedrock regions not specified
  default_service_region = length(local.bedrock_regions) > 0 ? local.bedrock_regions[0] : data.aws_region.current.name

  # Determine the actual region each service will use
  polly_region      = var.aws_polly_region != null ? var.aws_polly_region : local.default_service_region
  comprehend_region = var.aws_comprehend_region != null ? var.aws_comprehend_region : local.default_service_region
  transcribe_region = var.aws_transcribe_region != null ? var.aws_transcribe_region : local.default_service_region
  translate_region  = var.aws_translate_region != null ? var.aws_translate_region : local.default_service_region

  # Check if each service is configured for the current region
  polly_in_current_region      = local.polly_region == data.aws_region.current.name
  comprehend_in_current_region = local.comprehend_region == data.aws_region.current.name
  transcribe_in_current_region = local.transcribe_region == data.aws_region.current.name
  translate_in_current_region  = local.translate_region == data.aws_region.current.name
  bedrock_in_current_region    = length(local.bedrock_regions) == 0 || contains(local.bedrock_regions, data.aws_region.current.name)

  # Check if Secrets Manager is needed for API key authentication
  secretsmanager_needed = var.api_key_secretsmanager_secret != null

  # Check if any AWS service region differs from current region
  # VPC endpoints only work within the same region, so cross-region access requires internet
  cross_region_access_needed = (
    !local.polly_in_current_region ||
    !local.comprehend_in_current_region ||
    !local.transcribe_in_current_region ||
    !local.translate_in_current_region ||
    !local.bedrock_in_current_region
  )

  # Build VPC endpoints list dynamically based on which services are in the current region
  vpc_endpoints_core = concat(
    [
      "s3",   # S3 file storage (always needed, and free)
      "ssm",  # Systems Manager Parameter Store (for API key via SSM)
      "logs", # CloudWatch Logs (always needed)
    ],
    local.secretsmanager_needed ? ["secretsmanager"] : [],
    local.bedrock_in_current_region ? ["bedrock-runtime", "bedrock"] : [],
    local.polly_in_current_region ? ["polly"] : [],
    local.transcribe_in_current_region ? ["transcribe"] : [],
    local.comprehend_in_current_region ? ["comprehend"] : [],
    local.translate_in_current_region ? ["translate"] : [],
  )

  # Internet access required
  internet_access_required = local.cross_region_access_needed || var.aws_bedrock_marketplace_auto_subscribe != false
}

module "vpc" {
  source  = "JGoutin/vpc/aws"
  version = "~> 1.0"

  name_prefix                 = local.name
  internet_access_allowed     = local.internet_access_required
  nat_gateways_allowed        = var.nat_gateways_allowed
  vpc_endpoints_allowed       = var.vpc_endpoints_allowed
  availability_zones_count    = var.availability_zones_count
  subnets_ids                 = var.subnet_ids
  security_group_id           = var.security_group_id
  vpc_cidr                    = var.vpc_cidr
  vpc_flow_log_enabled        = var.vpc_flow_log_enabled
  vpc_flow_log_retention_days = var.cloudwatch_logs_retention_in_days
  kms_key_id                  = module.kms_key.id
  kms_policy_dependency       = module.kms_key.policy_dependency
  vpc_endpoints_services = concat(
    local.vpc_endpoints_core,
    local.ecs_service ? ["ecr.dkr", "ecr.api", "metering-marketplace"] : [],
  )
  public_subnets_enabled = var.alb_enabled && var.alb_public
  public_to_app_ports = {
    "http" = {
      from_port = local.port
      to_port   = local.port
      protocol  = "tcp"
    }
  }
  public_ingress_ports = merge(
    {
      "http" = {
        from_port = 80
      }
    },
    local.certificate_will_exist ? {
      "https" = {
        from_port = 443
      }
    } : {}
  )
}

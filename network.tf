/*
Provision a dedicated VPC for the projet, or use user provided subnets.
*/

locals {
  # Use Bedrock regions list directly
  bedrock_regions = var.aws_bedrock_regions != null ? var.aws_bedrock_regions : []

  current_region = data.aws_region.current.region

  # Regions Bedrock may be called in, defaulting to the current one
  candidate_regions = length(local.bedrock_regions) > 0 ? local.bedrock_regions : [local.current_region]

  # Regions each service may be called in: an explicit setting pins the service
  # to that single region, otherwise every Bedrock region is a candidate and the
  # server fails over between them.
  polly_regions      = var.aws_polly_region != null ? [var.aws_polly_region] : local.candidate_regions
  comprehend_regions = var.aws_comprehend_region != null ? [var.aws_comprehend_region] : local.candidate_regions
  transcribe_regions = var.aws_transcribe_region != null ? [var.aws_transcribe_region] : local.candidate_regions
  translate_regions  = var.aws_translate_region != null ? [var.aws_translate_region] : local.candidate_regions

  # Check if each service may be called in the current region
  polly_in_current_region      = contains(local.polly_regions, local.current_region)
  comprehend_in_current_region = contains(local.comprehend_regions, local.current_region)
  transcribe_in_current_region = contains(local.transcribe_regions, local.current_region)
  translate_in_current_region  = contains(local.translate_regions, local.current_region)
  bedrock_in_current_region    = contains(local.candidate_regions, local.current_region)

  # Check if Secrets Manager is needed for API key authentication
  secretsmanager_needed = var.api_key_secretsmanager_secret != null

  # Check if any AWS service may be called outside the current region
  # VPC endpoints only work within the same region, so cross-region access requires internet
  cross_region_access_needed = length(setsubtract(distinct(concat(
    local.candidate_regions,
    local.polly_regions,
    local.comprehend_regions,
    local.transcribe_regions,
    local.translate_regions,
  )), [local.current_region])) > 0

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
  source = "JGoutin/vpc/aws"
  # 1.4 is the first release whose ipv6_enabled reports the subnets rather than
  # whether the module created them, which the dual-stack decisions below rely on.
  version = "~> 1.4"

  name_prefix                                = local.name
  tags                                       = local.apn_tags
  internet_access_allowed                    = local.internet_access_required
  nat_gateways_allowed                       = var.nat_gateways_allowed
  vpc_endpoints_allowed                      = var.vpc_endpoints_allowed
  compliance_vpc_endpoints_enabled           = var.compliance_vpc_endpoints_enabled
  guardduty_vpc_endpoint_enabled             = var.guardduty_vpc_endpoint_enabled
  dns_firewall_enabled                       = var.dns_firewall_enabled
  dns_firewall_managed_domain_list_ids       = var.dns_firewall_managed_domain_list_ids
  dns_firewall_action                        = var.dns_firewall_action
  dns_firewall_advanced_enabled              = var.dns_firewall_advanced_enabled
  dns_firewall_advanced_confidence_threshold = var.dns_firewall_advanced_confidence_threshold
  dns_firewall_priority                      = var.dns_firewall_priority
  availability_zones_count                   = var.availability_zones_count
  subnets_ids                                = var.subnet_ids
  security_group_id                          = var.security_group_id
  vpc_cidr                                   = var.vpc_cidr
  vpc_flow_log_enabled                       = var.vpc_flow_log_enabled
  vpc_flow_log_retention_days                = var.cloudwatch_logs_retention_in_days
  kms_key_id                                 = module.kms_key.id
  kms_policy_dependency                      = module.kms_key.policy_dependency
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

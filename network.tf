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

  # The vector store indexing queue is reached in the single region its URL names, with no
  # failover, and only when durable indexing is enabled.
  sqs_regions           = local.sqs_vector_store_enabled ? [local.sqs_vector_store_queue_region] : []
  sqs_in_current_region = contains(local.sqs_regions, local.current_region)

  # The vector bucket is reached in the single region it lives in, with no failover, and only
  # when the Vector Stores API is enabled.
  s3vectors_regions           = local.vector_stores_enabled ? [local.s3_vectors_region] : []
  s3vectors_in_current_region = contains(local.s3vectors_regions, local.current_region)

  # Check if any AWS service may be called outside the current region
  # VPC endpoints only work within the same region, so cross-region access requires internet
  cross_region_access_needed = length(setsubtract(distinct(concat(
    local.candidate_regions,
    local.polly_regions,
    local.comprehend_regions,
    local.transcribe_regions,
    local.translate_regions,
    local.sqs_regions,
    local.s3vectors_regions,
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
    local.sqs_in_current_region ? ["sqs"] : [],
    local.s3vectors_in_current_region ? ["s3vectors"] : [],
    # Gateway endpoint like s3: free, so it is added on the feature alone rather than weighed
    # against a monthly cost. The table always lives in the deployment region.
    local.create_dynamodb_table ? ["dynamodb"] : [],
  )

  # Internet access required. WebRTC media mode counts too: callers and the
  # STUN server are on the internet, and with nat_gateways_allowed = false
  # (which the mode requires) this is also what gives the task its public IP.
  internet_access_required = local.cross_region_access_needed || var.aws_bedrock_marketplace_auto_subscribe != false || var.realtime_webrtc_media_enabled

  # The VPC module only owns a network of its own when no subnets were supplied.
  vpc_created = length(var.subnet_ids) == 0
}

# Fails the plan when compliance/GuardDuty interface endpoints are requested but the
# application subnets end up public, leaving no private subnet to place them in: a
# validation surface, holding no infrastructure. realtime_webrtc_media_enabled is
# excluded here since it already fails this same combination with a mode-specific message.
resource "terraform_data" "enforced_vpc_endpoints_validation" {
  count = (var.compliance_vpc_endpoints_enabled || var.guardduty_vpc_endpoint_enabled) && !var.realtime_webrtc_media_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = !(local.vpc_created && local.internet_access_required && !local.nat_gateways_allowed)
      error_message = "compliance_vpc_endpoints_enabled/guardduty_vpc_endpoint_enabled cannot be combined with nat_gateways_allowed = false while internet access is required (the default, driven by aws_bedrock_marketplace_auto_subscribe or cross-region service usage): the application subnets become public, leaving no private subnet for the endpoint's network interface, so the endpoint would silently not be created. Set nat_gateways_allowed = true (or leave it unset), or turn off compliance_vpc_endpoints_enabled/guardduty_vpc_endpoint_enabled."
    }
  }
}

module "vpc" {
  source = "JGoutin/vpc/aws"
  # 1.6 is the first release whose ipv6_enabled answers for provided subnets that
  # carry no IPv6 block, which every dual-stack decision below relies on, and the
  # first that opens application-subnet network ACL flows other than TCP, which
  # the WebRTC media mode relies on.
  version = "~> 1.6"

  name_prefix                                = local.name
  tags                                       = local.tags
  internet_access_allowed                    = local.internet_access_required
  nat_gateways_allowed                       = local.nat_gateways_allowed
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
  # The WebRTC media path, which is UDP and reaches the task directly. Both are empty when the
  # mode is off, leaving the application subnets' network ACL as it was, and on operator-supplied
  # subnets, where the ACL belongs to the operator and the module writes no rule in it.
  internet_to_app_ports = local.vpc_created ? local.realtime_webrtc_nacl_ingress : {}
  app_to_internet_ports = local.vpc_created ? local.realtime_webrtc_nacl_egress : {}
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

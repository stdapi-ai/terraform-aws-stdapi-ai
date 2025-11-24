# stdapi.ai - AWS Marketplace Terraform Module

**Deploy stdapi.ai from AWS Marketplace** - A production-ready, OpenAI-compatible API for Amazon Bedrock and AWS AI services.

## What is stdapi.ai?

**stdapi.ai** is an AWS Marketplace product that provides an OpenAI-compatible API gateway for Amazon Bedrock and AWS AI services. This Terraform module simplifies the deployment and management of stdapi.ai infrastructure on AWS.

🌐 **Learn more**: Visit [stdapi.ai official website](https://stdapi.ai) for complete product information, pricing, and documentation.

🛒 **AWS Marketplace**: Subscribe to stdapi.ai on [AWS Marketplace](https://aws.amazon.com/marketplace/pp/prodview-su2dajk5zawpo) to get started.

## Why stdapi.ai?

- **OpenAI SDK Compatible** - Use existing OpenAI client libraries without code changes
- **Amazon Bedrock Integration** - Access Claude, Llama, Mistral, and all Bedrock models
- **Multimodal Support** - Handle text, images, and documents
- **AWS AI Services** - Integrated Polly (TTS), Transcribe (STT), and Translate
- **Enterprise-Ready** - Built-in security, monitoring, and compliance features

## Module Features

This Terraform module provides complete infrastructure deployment for stdapi.ai, including:

- **Serverless Compute**: ECS Fargate with auto-scaling (0.25-16 vCPU)
- **Load Balancing**: Application Load Balancer with HTTPS/TLS support
- **Networking**: VPC with public/private subnets and VPC endpoints
- **Security**: WAF protection, KMS encryption, IAM roles
- **Monitoring**: CloudWatch dashboards and intelligent alarms
- **Storage**: S3 buckets with encryption and lifecycle policies

## Getting Started

📖 **For complete deployment examples, configuration options, and best practices**, see the [Getting Started Guide](https://stdapi.ai/operations_getting_started/).

The guide includes:
- **Quick Start**: Deploy in 5 minutes with minimal configuration
- **Production Deployment**: Enterprise-ready setup with HTTPS, WAF, and monitoring
- **Cost-Optimized Deployment**: Ultra-low cost configuration for development
- **Integration Examples**: Deploy into existing VPC and infrastructure
- **Regional Buckets**: Setup for Amazon Bedrock multimodal operations

### Prerequisites

1. **Subscribe to stdapi.ai** on [AWS Marketplace](https://aws.amazon.com/marketplace/pp/prodview-su2dajk5zawpo)
2. Install [Terraform](https://www.terraform.io/downloads) or [OpenTofu](https://opentofu.org/docs/intro/install/) >= 1.5
3. Configure [AWS credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)

### Minimal Example

```hcl
module "stdapi_ai" {
  source = "stdapi-ai/stdapi-ai/aws"
}
```

### Production Example

See [Example 2: Production Deployment](../../docs/operations_getting_started.md#example-2-production-deployment-fully-featured) in the Getting Started Guide for a complete production-ready configuration with HTTPS, WAF, monitoring, and regional S3 buckets.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────┬─────────────────────────────────────────────┘
                 │
          ┌──────▼──────┐
          │     WAF     │ (Optional)
          └──────┬──────┘
                 │
          ┌──────▼──────┐
          │     ALB     │ HTTPS/HTTP
          │  (Public)   │
          └──────┬──────┘
                 │
    ┌────────────┼────────────┐
    │         VPC              │
    │  ┌────────▼────────┐    │
    │  │  ECS Fargate    │    │
    │  │  ┌──────────┐   │    │
    │  │  │stdapi.ai │   │    │───┐
    │  │  │Container │   │    │   │ KMS Encrypted
    │  │  └──────────┘   │    │   │
    │  │   (Private)     │    │   ▼
    │  └─────────────────┘    │  ┌─────────────┐
    │                         │  │ S3 Bucket   │
    │  ┌─────────────────┐    │  └─────────────┘
    │  │ VPC Endpoints   │    │
    │  │ (Bedrock, S3,   │◄───┤
    │  │  Secrets, Logs) │    │
    │  └─────────────────┘    │
    └──────────────────────────┘
                 │
          ┌──────▼──────┐
          │  CloudWatch │
          └─────────────┘
```

## Documentation

- **[Getting Started Guide](https://stdapi.ai/operations_getting_started/)** - Complete deployment examples and configuration
- **[Configuration Reference](https://stdapi.ai/operations_configuration/)** - Environment variables and module parameters
- **[API Documentation](https://stdapi.ai/api_overview/)** - OpenAI-compatible API endpoints
- **[Roadmap](https://stdapi.ai/roadmap/)** - Feature compatibility and future plans

## Requirements

- **AWS Marketplace Subscription** - Active subscription required
- **Terraform** - Version >= 1.5.0
- **AWS Provider** - Version >= 5.0
- **AWS Regions** - All regions with ECS Fargate support

---

# Terraform Documentation

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >=5 |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_kms_key"></a> [kms\_key](#module\_kms\_key) | JGoutin/kms-key/aws | ~> 1.0 |
| <a name="module_server"></a> [server](#module\_server) | JGoutin/ecs-fargate/aws | ~> 1.1 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | JGoutin/vpc/aws | ~> 1.0 |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_cloudwatch_log_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_metric_filter.error_critical_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_metric_alarm.error_critical_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_query_definition.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_query_definition) | resource |
| [aws_iam_policy.server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_lb.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.acm_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.main_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.alb_to_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_http_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_http_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_https_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_https_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.ecs_from_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_wafv2_web_acl.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [aws_wafv2_web_acl_logging_configuration.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |
| [random_id.main](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.api_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.log_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.main_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.by_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_s3_bucket.user_provided](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarms_enabled"></a> [alarms\_enabled](#input\_alarms\_enabled) | Enable CloudWatch alarms. This should be set to true if sns\_topic\_arn is provided. | `bool` | `false` | no |
| <a name="input_alb_certificate_arn"></a> [alb\_certificate\_arn](#input\_alb\_certificate\_arn) | Existing ACM certificate ARN to attach to the HTTPS listener. When specified, takes precedence over certificate\_create. If not specified and certificate\_create is true, a certificate will be created automatically. | `string` | `null` | no |
| <a name="input_alb_certificate_create"></a> [alb\_certificate\_create](#input\_alb\_certificate\_create) | If true, create an ACM certificate and validate it via DNS. Only used when certificate\_arn is not specified. Requires route53\_zone\_id, domain\_name, and route53\_zone\_private=false. | `bool` | `true` | no |
| <a name="input_alb_domain_name"></a> [alb\_domain\_name](#input\_alb\_domain\_name) | Primary domain name for the application (e.g., api.example.com). Creates Route53 A record and ACM certificate. If route53\_zone\_id is not specified, automatically looks up the most specific parent domain zone. | `string` | `null` | no |
| <a name="input_alb_enabled"></a> [alb\_enabled](#input\_alb\_enabled) | If true, create an Application Load Balancer for the ECS service. Cannot be used with external subnets (subnet\_ids). | `bool` | `false` | no |
| <a name="input_alb_idle_timeout"></a> [alb\_idle\_timeout](#input\_alb\_idle\_timeout) | The time in seconds that the connection is allowed to be idle. Range: 1-4000 seconds. Default to 3600 (1 hour) to support slow LLM responses and long-running operations like AWS Transcribe. | `number` | `3600` | no |
| <a name="input_alb_ingress_ipv4_cidrs"></a> [alb\_ingress\_ipv4\_cidrs](#input\_alb\_ingress\_ipv4\_cidrs) | List of IPv4 CIDR blocks allowed to access the ALB. Default to ['0.0.0.0/0'] for public access. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_alb_ingress_ipv6_cidrs"></a> [alb\_ingress\_ipv6\_cidrs](#input\_alb\_ingress\_ipv6\_cidrs) | List of IPv6 CIDR blocks allowed to access the ALB. Default to ['::/0'] for public access. | `list(string)` | <pre>[<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_alb_public"></a> [alb\_public](#input\_alb\_public) | If true, create a public (internet-facing) ALB with dedicated public subnets. If false, create a private (internal) ALB using app subnets. | `bool` | `false` | no |
| <a name="input_alb_route53_zone_id"></a> [alb\_route53\_zone\_id](#input\_alb\_route53\_zone\_id) | Route53 hosted zone ID for DNS records. If not specified, automatically infers the zone from the parent domain of domain\_name (e.g., 'api.example.com' → 'example.com', 'api.sandbox.example.com' → 'sandbox.example.com'). | `string` | `null` | no |
| <a name="input_alb_route53_zone_name"></a> [alb\_route53\_zone\_name](#input\_alb\_route53\_zone\_name) | Route53 hosted zone name for DNS records (e.g., 'example.com'). Alternative to route53\_zone\_id - module will look up the zone ID automatically. If specified with domain\_name, creates DNS records and ACM certificate. | `string` | `null` | no |
| <a name="input_alb_route53_zone_private"></a> [alb\_route53\_zone\_private](#input\_alb\_route53\_zone\_private) | If true, the Route53 zone is private. If false, it's public. Used when looking up the zone by name. | `bool` | `false` | no |
| <a name="input_alb_waf_block_anonymous_ips"></a> [alb\_waf\_block\_anonymous\_ips](#input\_alb\_waf\_block\_anonymous\_ips) | If true, block requests from anonymous IP addresses (VPNs, proxies, Tor exit nodes). | `bool` | `false` | no |
| <a name="input_alb_waf_enabled"></a> [alb\_waf\_enabled](#input\_alb\_waf\_enabled) | If true, create a WAF WebACL and associate it with the ALB (requires alb\_enabled=true). | `bool` | `false` | no |
| <a name="input_alb_waf_logging_enabled"></a> [alb\_waf\_logging\_enabled](#input\_alb\_waf\_logging\_enabled) | If true, enable WAF logging to CloudWatch Logs. | `bool` | `true` | no |
| <a name="input_alb_waf_rate_limit"></a> [alb\_waf\_rate\_limit](#input\_alb\_waf\_rate\_limit) | Maximum number of requests allowed from a single IP address in a 5-minute period. If null, rate limiting is disabled. | `number` | `null` | no |
| <a name="input_api_key"></a> [api\_key](#input\_api\_key) | API key for client authentication. When specified, all API requests must include this key. Mutually exclusive with api\_key\_create, api\_key\_ssm\_parameter, and api\_key\_secretsmanager\_secret. | `string` | `null` | no |
| <a name="input_api_key_create"></a> [api\_key\_create](#input\_api\_key\_create) | If true, generate and return an API key using the 'api\_key' output. When specified, all API requests must include this key. Mutually exclusive with api\_key, api\_key\_ssm\_parameter, and api\_key\_secretsmanager\_secret. | `bool` | `false` | no |
| <a name="input_api_key_secretsmanager_key"></a> [api\_key\_secretsmanager\_key](#input\_api\_key\_secretsmanager\_key) | Key name within the AWS Secrets Manager secret containing the API key. Only used when api\_key\_secretsmanager\_secret is specified. | `string` | `null` | no |
| <a name="input_api_key_secretsmanager_secret"></a> [api\_key\_secretsmanager\_secret](#input\_api\_key\_secretsmanager\_secret) | AWS Secrets Manager secret name containing the API key. Mutually exclusive with api\_key\_create, api\_key, and api\_key\_ssm\_parameter. When using this option, you must create an IAM policy granting secretsmanager:GetSecretValue permission and pass the policy ARN to var.ecs\_task\_role\_policy\_arns. | `string` | `null` | no |
| <a name="input_api_key_ssm_parameter"></a> [api\_key\_ssm\_parameter](#input\_api\_key\_ssm\_parameter) | AWS Systems Manager Parameter Store parameter name containing the API key. Mutually exclusive with api\_key\_create, api\_key, and api\_key\_secretsmanager\_secret. When using this option, you must create an IAM policy granting ssm:GetParameter permission and pass the policy ARN to var.ecs\_task\_role\_policy\_arns. | `string` | `null` | no |
| <a name="input_autoscaling_alb_target_requests_per_target"></a> [autoscaling\_alb\_target\_requests\_per\_target](#input\_autoscaling\_alb\_target\_requests\_per\_target) | Target number of ALB requests per ECS task for auto-scaling. If null or ALB not enabled, request-based scaling is disabled. | `number` | `null` | no |
| <a name="input_autoscaling_cpu_target_percent"></a> [autoscaling\_cpu\_target\_percent](#input\_autoscaling\_cpu\_target\_percent) | Target CPU utilization percentage for auto-scaling. If null, uses AWS default. | `number` | `null` | no |
| <a name="input_autoscaling_max_capacity"></a> [autoscaling\_max\_capacity](#input\_autoscaling\_max\_capacity) | Maximum number of ECS tasks for auto-scaling. If null, uses AWS default. | `number` | `null` | no |
| <a name="input_autoscaling_memory_target_percent"></a> [autoscaling\_memory\_target\_percent](#input\_autoscaling\_memory\_target\_percent) | Target memory utilization percentage for auto-scaling. If null, memory-based scaling is disabled. | `number` | `null` | no |
| <a name="input_autoscaling_min_capacity"></a> [autoscaling\_min\_capacity](#input\_autoscaling\_min\_capacity) | Minimum number of ECS tasks. If not specified, defaults to the number of availability zones. | `number` | `null` | no |
| <a name="input_autoscaling_scale_in_cooldown"></a> [autoscaling\_scale\_in\_cooldown](#input\_autoscaling\_scale\_in\_cooldown) | Time in seconds after a scale-in activity completes before another scale-in can start. If null, uses AWS default. | `number` | `null` | no |
| <a name="input_autoscaling_scale_out_cooldown"></a> [autoscaling\_scale\_out\_cooldown](#input\_autoscaling\_scale\_out\_cooldown) | Time in seconds after a scale-out activity completes before another scale-out can start. If null, uses AWS default. | `number` | `null` | no |
| <a name="input_autoscaling_schedule_start"></a> [autoscaling\_schedule\_start](#input\_autoscaling\_schedule\_start) | Schedule to start the service if stopped. Format: cron(fields) or at(yyyy-mm-ddThh:mm:ss) in UTC. | `string` | `null` | no |
| <a name="input_autoscaling_schedule_stop"></a> [autoscaling\_schedule\_stop](#input\_autoscaling\_schedule\_stop) | Schedule to stop/pause the service (scale to 0). Format: cron(fields) or at(yyyy-mm-ddThh:mm:ss) in UTC. | `string` | `null` | no |
| <a name="input_autoscaling_spot_on_demand_min_capacity"></a> [autoscaling\_spot\_on\_demand\_min\_capacity](#input\_autoscaling\_spot\_on\_demand\_min\_capacity) | Minimum number of on-demand tasks when autoscaling\_spot\_percent is enabled. If not specified, defaults to autoscaling\_min\_capacity. | `number` | `null` | no |
| <a name="input_autoscaling_spot_percent"></a> [autoscaling\_spot\_percent](#input\_autoscaling\_spot\_percent) | Percent of capacity over the minimum capacity to run with Fargate Spot (~70% cost discount). Set to 100 to use only Spot instances. Set to 0 to disable Spot instances. | `number` | `0` | no |
| <a name="input_availability_zones_count"></a> [availability\_zones\_count](#input\_availability\_zones\_count) | Maximum count of availability zones to provision with the dedicated VPC. Default to all available availability zones. | `number` | `null` | no |
| <a name="input_aws_bedrock_cross_region_inference"></a> [aws\_bedrock\_cross\_region\_inference](#input\_aws\_bedrock\_cross\_region\_inference) | If true, allow cross region inference to be used. Default to true. | `bool` | `null` | no |
| <a name="input_aws_bedrock_cross_region_inference_global"></a> [aws\_bedrock\_cross\_region\_inference\_global](#input\_aws\_bedrock\_cross\_region\_inference\_global) | If True, allow 'global' cross region inference that can route requests to any region, worldwide. Default to true. | `bool` | `null` | no |
| <a name="input_aws_bedrock_guardrail_identifier"></a> [aws\_bedrock\_guardrail\_identifier](#input\_aws\_bedrock\_guardrail\_identifier) | Amazon Bedrock Guardrails ID. | `string` | `null` | no |
| <a name="input_aws_bedrock_guardrail_trace"></a> [aws\_bedrock\_guardrail\_trace](#input\_aws\_bedrock\_guardrail\_trace) | Amazon Bedrock Guardrails trace setting: disabled, enabled, or enabled\_full. | `string` | `null` | no |
| <a name="input_aws_bedrock_guardrail_version"></a> [aws\_bedrock\_guardrail\_version](#input\_aws\_bedrock\_guardrail\_version) | Amazon Bedrock Guardrails version. | `string` | `null` | no |
| <a name="input_aws_bedrock_legacy"></a> [aws\_bedrock\_legacy](#input\_aws\_bedrock\_legacy) | If true, allow legacy Bedrock models to be used. Default to true. | `bool` | `null` | no |
| <a name="input_aws_bedrock_marketplace_auto_subscribe"></a> [aws\_bedrock\_marketplace\_auto\_subscribe](#input\_aws\_bedrock\_marketplace\_auto\_subscribe) | If true, allow the server to automatically subscribe to new models in the AWS Marketplace. Default to true. | `bool` | `null` | no |
| <a name="input_aws_bedrock_regions"></a> [aws\_bedrock\_regions](#input\_aws\_bedrock\_regions) | List of AWS regions where Bedrock AI models are available. Default to the current region. | `list(string)` | `null` | no |
| <a name="input_aws_comprehend_region"></a> [aws\_comprehend\_region](#input\_aws\_comprehend\_region) | AWS region for Comprehend language detection service. Default to first var.aws\_bedrock\_regions region or the current region. | `string` | `null` | no |
| <a name="input_aws_polly_region"></a> [aws\_polly\_region](#input\_aws\_polly\_region) | AWS region for Polly text-to-speech service. Default to first var.aws\_bedrock\_regions region or the current region. | `string` | `null` | no |
| <a name="input_aws_s3_accelerate"></a> [aws\_s3\_accelerate](#input\_aws\_s3\_accelerate) | Enable S3 Transfer Acceleration for presigned URLs. Default to false. | `bool` | `null` | no |
| <a name="input_aws_s3_bucket"></a> [aws\_s3\_bucket](#input\_aws\_s3\_bucket) | Existing S3 bucket name for storing generated files and application data. When specified, takes precedence over aws\_s3\_bucket\_create. If not specified and aws\_s3\_bucket\_create is true, a bucket will be created automatically. | `string` | `null` | no |
| <a name="input_aws_s3_bucket_create"></a> [aws\_s3\_bucket\_create](#input\_aws\_s3\_bucket\_create) | If true, create an S3 bucket for the application. Only used when aws\_s3\_bucket is not specified. When aws\_s3\_bucket is specified, this value is ignored. | `bool` | `true` | no |
| <a name="input_aws_s3_buckets_kms_keys_arns"></a> [aws\_s3\_buckets\_kms\_keys\_arns](#input\_aws\_s3\_buckets\_kms\_keys\_arns) | List of KMS key ARNs used to encrypt the regional S3 buckets. Required to grant the server permissions to access encrypted regional buckets. | `list(string)` | `[]` | no |
| <a name="input_aws_s3_regional_buckets"></a> [aws\_s3\_regional\_buckets](#input\_aws\_s3\_regional\_buckets) | Region-specific S3 buckets for temporary file storage during Bedrock operations.<br/>Keys are AWS region identifiers, values are bucket names.<br/><br/>Example: { "us-east-1" = "my-bucket-us-east-1", "us-west-2" = "my-bucket-us-west-2" }<br/><br/>Required for Bedrock operations with multimodal input or document processing.<br/>Use the companion module 'stdapi-ai/stdapi-ai-s3-regional-bucket' to create these buckets automatically.<br/>See: https://github.com/stdapi-ai/terraform-aws-stdapi-ai-s3-regional-bucket | `map(string)` | `null` | no |
| <a name="input_aws_s3_tmp_prefix"></a> [aws\_s3\_tmp\_prefix](#input\_aws\_s3\_tmp\_prefix) | S3 prefix (folder path) for temporary files used during job processing. Default to 'tmp/'. | `string` | `null` | no |
| <a name="input_aws_transcribe_region"></a> [aws\_transcribe\_region](#input\_aws\_transcribe\_region) | AWS region for Transcribe speech-to-text service. Default to first var.aws\_bedrock\_regions region or the current region. | `string` | `null` | no |
| <a name="input_aws_transcribe_s3_bucket"></a> [aws\_transcribe\_s3\_bucket](#input\_aws\_transcribe\_s3\_bucket) | AWS S3 bucket name for temporary file storage during transcription. Defaults to aws\_s3\_bucket if not specified. | `string` | `null` | no |
| <a name="input_aws_translate_region"></a> [aws\_translate\_region](#input\_aws\_translate\_region) | AWS region for Translate text translation service. Default to first var.aws\_bedrock\_regions region or the current region. | `string` | `null` | no |
| <a name="input_cloudwatch_logs_retention_in_days"></a> [cloudwatch\_logs\_retention\_in\_days](#input\_cloudwatch\_logs\_retention\_in\_days) | Cloudwatch logs retention in days. | `number` | `365` | no |
| <a name="input_container_insight"></a> [container\_insight](#input\_container\_insight) | Container insight configuration. Valid values: 'enhanced', 'enabled', 'disabled'. Default to 'enhanced'. | `string` | `"enabled"` | no |
| <a name="input_cors_allow_origins"></a> [cors\_allow\_origins](#input\_cors\_allow\_origins) | List of origins allowed to make cross-origin requests (CORS). Use ['*'] to allow all origins. Default to no CORS headers. | `list(string)` | `null` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | ECS task CPU count. Valid values: 0.25, 0.5, 1, 2, 4, 8 & 16. Default of 0.25 vCPU is suitable for common use cases (text generation, embeddings). Increase for intensive workloads (multimodal requests, large LLM models). | `number` | `0.25` | no |
| <a name="input_cpu_architecture"></a> [cpu\_architecture](#input\_cpu\_architecture) | CPU architecture. Valid values: 'X86\_64' or 'ARM64'. | `string` | `"ARM64"` | no |
| <a name="input_default_model_params"></a> [default\_model\_params](#input\_default\_model\_params) | Default inference parameters applied to specific models automatically. JSON string format. | `string` | `null` | no |
| <a name="input_default_tts_model"></a> [default\_tts\_model](#input\_default\_tts\_model) | Default text-to-speech model to use if not specified in the request. Default to 'amazon.polly-standard'. | `string` | `null` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | If true, enable deletion protection on eligible resources. | `bool` | `false` | no |
| <a name="input_ecs_task_role_policy_arns"></a> [ecs\_task\_role\_policy\_arns](#input\_ecs\_task\_role\_policy\_arns) | List of IAM policy ARNs to attach to the ECS task role. Use this to grant additional permissions to the ECS task, such as access to SSM parameters or Secrets Manager secrets specified in api\_key\_ssm\_parameter or api\_key\_secretsmanager\_secret. | `list(string)` | `[]` | no |
| <a name="input_enable_docs"></a> [enable\_docs](#input\_enable\_docs) | Enable interactive API documentation UI at /docs. Default to false. | `bool` | `null` | no |
| <a name="input_enable_gzip"></a> [enable\_gzip](#input\_enable\_gzip) | Enable GZip compression middleware for HTTP responses. Disabled by default. | `bool` | `null` | no |
| <a name="input_enable_openapi_json"></a> [enable\_openapi\_json](#input\_enable\_openapi\_json) | Enable OpenAPI JSON schema endpoint at /openapi.json. Default to false. | `bool` | `null` | no |
| <a name="input_enable_proxy_headers"></a> [enable\_proxy\_headers](#input\_enable\_proxy\_headers) | Enable ProxyHeadersMiddleware to trust X-Forwarded-* headers from reverse proxies. Automatically enabled when var.alb\_enabled is true and var.log\_client\_ip is true. | `bool` | `null` | no |
| <a name="input_enable_redoc"></a> [enable\_redoc](#input\_enable\_redoc) | Enable ReDoc API documentation UI at /redoc. Default to false. | `bool` | `null` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | If specified, directly use this KMS key instead of creating a dedicated one for the application. | `string` | `null` | no |
| <a name="input_log_client_ip"></a> [log\_client\_ip](#input\_log\_client\_ip) | If True, log the client IP address for each request and add it to OpenTelemetry spans. Default to false. | `bool` | `null` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Minimum logging level to output: info, warning, error, critical, or disabled. Default to info. | `string` | `null` | no |
| <a name="input_log_request_params"></a> [log\_request\_params](#input\_log\_request\_params) | If True, add requests and responses parameters to logs. Should not be enabled in production. Default to false. | `bool` | `null` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | ECS task memory (MiB). Valid values depends on the var.container\_cpu value (x1024), see the ECS documentation for more information. Default of 512 MiB is suitable for common use cases (text generation, embeddings). Increase for intensive workloads (multimodal requests, large LLM models). | `number` | `512` | no |
| <a name="input_model_cache_seconds"></a> [model\_cache\_seconds](#input\_model\_cache\_seconds) | Cache lifetime in seconds for the Bedrock models list. | `number` | `null` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix to add to all created resources names. | `string` | `"stdapiai"` | no |
| <a name="input_nat_gateways_allowed"></a> [nat\_gateways\_allowed](#input\_nat\_gateways\_allowed) | If true, NAT gateways are used to give internet access to the application. If Disabled and internet access is required, application subnets will be public. Disable only if cost is privileged over security. | `bool` | `true` | no |
| <a name="input_openai_routes_prefix"></a> [openai\_routes\_prefix](#input\_openai\_routes\_prefix) | OpenAI API compatible routes prefix. | `string` | `null` | no |
| <a name="input_otel_enabled"></a> [otel\_enabled](#input\_otel\_enabled) | Enable OpenTelemetry distributed tracing. Default to false. | `bool` | `null` | no |
| <a name="input_otel_exporter_endpoint"></a> [otel\_exporter\_endpoint](#input\_otel\_exporter\_endpoint) | OpenTelemetry traces export endpoint URL. | `string` | `null` | no |
| <a name="input_otel_sample_rate"></a> [otel\_sample\_rate](#input\_otel\_sample\_rate) | OpenTelemetry trace sampling rate (0.0 to 1.0). | `number` | `null` | no |
| <a name="input_otel_service_name"></a> [otel\_service\_name](#input\_otel\_service\_name) | Service name identifier for OpenTelemetry traces. Default to 'stdapi.ai'. | `string` | `null` | no |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | If specified and 'subnet\_ids' is specified, use this security group instead of creating a new one giving access to internet and AWS services. | `string` | `null` | no |
| <a name="input_service_discovery_dns_name"></a> [service\_discovery\_dns\_name](#input\_service\_discovery\_dns\_name) | DNS name for service discovery. By default, uses the service name. Only if service\_discovery\_dns\_namespace\_id is specified. | `string` | `null` | no |
| <a name="input_service_discovery_dns_namespace_id"></a> [service\_discovery\_dns\_namespace\_id](#input\_service\_discovery\_dns\_namespace\_id) | If specified, enable Service discovery on the ECS service and attach it to this Cloud Map namespace. | `string` | `null` | no |
| <a name="input_sns_topic_arn"></a> [sns\_topic\_arn](#input\_sns\_topic\_arn) | SNS topic ARN for CloudWatch alarms. If specified, CloudWatch alarms will be created for high memory usage and unhealthy containers. | `string` | `null` | no |
| <a name="input_ssrf_protection_block_private_networks"></a> [ssrf\_protection\_block\_private\_networks](#input\_ssrf\_protection\_block\_private\_networks) | Enable SSRF protection by blocking requests to private/local networks. When enabled, the server will reject requests to RFC 1918 private addresses (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16), loopback, link-local, reserved, and multicast addresses. Default to true. | `bool` | `null` | no |
| <a name="input_strict_input_validation"></a> [strict\_input\_validation](#input\_strict\_input\_validation) | If True, raise error on extra fields in input request. Default to false. | `bool` | `null` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | If specified, directly use theses subnets instead of creating a dedicated VPC. | `list(string)` | `[]` | no |
| <a name="input_timezone"></a> [timezone](#input\_timezone) | Timezone for request date & time (IANA timezone identifier). Default to UTC. | `string` | `null` | no |
| <a name="input_tokens_estimation"></a> [tokens\_estimation](#input\_tokens\_estimation) | If True, estimate the number of tokens using a tokenizer when not directly returned by the model. Default to false. | `bool` | `null` | no |
| <a name="input_tokens_estimation_default_encoding"></a> [tokens\_estimation\_default\_encoding](#input\_tokens\_estimation\_default\_encoding) | Tiktoken Tokenizer encoding to use for token count estimation. | `string` | `null` | no |
| <a name="input_trusted_hosts"></a> [trusted\_hosts](#input\_trusted\_hosts) | List of trusted host header values for Host header validation. Supports wildcard subdomains. Disabled by default. | `list(string)` | `null` | no |
| <a name="input_version_to_deploy"></a> [version\_to\_deploy](#input\_version\_to\_deploy) | Container image version tag from AWS Marketplace. Leave unset to automatically use the latest stable version. Only override for testing or rollback purposes. | `string` | `"0.1.14"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the dedicated VPC. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_endpoints_allowed"></a> [vpc\_endpoints\_allowed](#input\_vpc\_endpoints\_allowed) | If true, VPC endpoints interfaces are privileged to give AWS services access to the application if no internet access is required. VPC endpoint Gateway are always provisioned. Disable only if cost is privileged over security. | `bool` | `true` | no |
| <a name="input_vpc_flow_log_enabled"></a> [vpc\_flow\_log\_enabled](#input\_vpc\_flow\_log\_enabled) | If true, enable VPC flow log. Disable only if cost is privileged over security. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the Application Load Balancer (only if ALB is enabled). |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the Application Load Balancer (only if ALB is enabled). |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | Security group ID of the Application Load Balancer (only if ALB is enabled). |
| <a name="output_alb_waf_web_acl_arn"></a> [alb\_waf\_web\_acl\_arn](#output\_alb\_waf\_web\_acl\_arn) | ARN of the WAF WebACL (only if WAF is enabled). |
| <a name="output_alb_waf_web_acl_id"></a> [alb\_waf\_web\_acl\_id](#output\_alb\_waf\_web\_acl\_id) | ID of the WAF WebACL (only if WAF is enabled). |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Zone ID of the Application Load Balancer (only if ALB is enabled). |
| <a name="output_api_key"></a> [api\_key](#output\_api\_key) | Returns API key value from var.api\_key or var.api\_key\_create. API key values from var.api\_key\_ssm\_parameter or var.api\_key\_secretsmanager\_secret are not returned. |
| <a name="output_application_url"></a> [application\_url](#output\_application\_url) | Application URL (uses domain name if configured, otherwise ALB DNS name). |
| <a name="output_aws_s3_tmp_prefix"></a> [aws\_s3\_tmp\_prefix](#output\_aws\_s3\_tmp\_prefix) | S3 prefix (folder path) for temporary files used during job processing. To pass to compagnon module. |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | Configuration S3 bucket ARN. |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | Configuration S3 bucket ID. |
| <a name="output_cloudwatch_log_groups_names"></a> [cloudwatch\_log\_groups\_names](#output\_cloudwatch\_log\_groups\_names) | CloudWatch log group names for each container in the server. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | ECS cluster name. |
| <a name="output_deletion_protection"></a> [deletion\_protection](#output\_deletion\_protection) | If true, enable deletion protection on eligible resources. To pass to compagnon module. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | KMS key ARN. |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | KMS key ID. |
| <a name="output_kms_policy_documents_json"></a> [kms\_policy\_documents\_json](#output\_kms\_policy\_documents\_json) | KMS policy documents to add to the policy of the key specified via var.kms\_key\_id. |
| <a name="output_name_prefix"></a> [name\_prefix](#output\_name\_prefix) | Name prefix for resources. To pass to compagnon module. |
| <a name="output_port"></a> [port](#output\_port) | Container port exposed by the application. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID for the ECS server service. |
| <a name="output_service_discovery_service_name"></a> [service\_discovery\_service\_name](#output\_service\_discovery\_service\_name) | Service discovery service name for the server (only if service discovery is enabled). |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | ECS service name. |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Subnets IDs where the ECS service is deployed. |
<!-- END_TF_DOCS -->
# stdapi.ai - Terraform Module for AWS

[![Terraform Module](https://img.shields.io/badge/Terraform-Registry%20module-844FBA?logo=terraform&logoColor=ffffff)](https://registry.terraform.io/modules/stdapi-ai/stdapi-ai/aws/latest)
[![OpenTofu Module](https://img.shields.io/badge/OpenTofu-Registry%20module-FFDA18?logo=opentofu&logoColor=ffffff)](https://search.opentofu.org/module/stdapi-ai/stdapi-ai/aws/latest)

**Deploy an OpenAI, Anthropic & Cohere compatible AI gateway on AWS.** ECS Fargate infrastructure with auto-scaling, private subnets, KMS encryption and least-privilege IAM by default; HTTPS, WAF, API key authentication and CloudWatch alarms are opt-in inputs — see [What this minimal configuration deploys](#minimal-deployment) and [What gets provisioned, and when](#what-gets-provisioned-and-when).

🌐 [Documentation](https://stdapi.ai) · 🚀 [Start 14-Day Free Trial](https://aws.amazon.com/marketplace/pp/prodview-su2dajk5zawpo) · 💻 [GitHub Repository](https://github.com/stdapi-ai/stdapi.ai)

## Quick Start

### Prerequisites

1. **[Subscribe to stdapi.ai](https://aws.amazon.com/marketplace/pp/prodview-su2dajk5zawpo)** on AWS Marketplace (14-day free trial included)
2. Install [Terraform](https://www.terraform.io/downloads) or [OpenTofu](https://opentofu.org/docs/intro/install/) >= 1.5 — see [Requirements](#requirements) for exact version constraints
3. Configure [AWS credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) with IAM permissions to create VPC, ECS, ALB, S3, KMS, IAM, and CloudWatch resources

Deployable in any AWS region with ECS Fargate support.

### Minimal Deployment

```hcl
module "stdapi_ai" {
  source  = "stdapi-ai/stdapi-ai/aws"
  version = "~> 1.0"
}
```

**What this minimal configuration deploys:**

- ECS Fargate service (auto-scaling, private subnets)
- Dedicated VPC with private app subnets, NAT gateways for outbound AWS access, and the free S3 gateway endpoint
- S3 bucket for generated and temporary files (KMS-encrypted)
- IAM roles (least privilege) and CloudWatch logs

**What it does NOT deploy** (you add these explicitly for production):

- ❌ No public endpoint — the service is only reachable from inside the VPC until you enable the ALB
- ❌ No HTTPS / custom domain
- ❌ No WAF
- ❌ No API key authentication

**Production-ready next step — add a public HTTPS endpoint with WAF and API key:**

```hcl
module "stdapi_ai" {
  source  = "stdapi-ai/stdapi-ai/aws"
  version = "~> 1.0"

  # Public HTTPS endpoint on a custom domain (ACM cert auto-issued via Route 53)
  alb_enabled           = true
  alb_public            = true
  alb_domain_name       = "api.example.com"
  alb_route53_zone_name = "example.com"

  # Protection
  alb_waf_enabled             = true
  alb_waf_rate_limit          = 2000
  alb_waf_block_anonymous_ips = true

  # Authentication — module generates a secure key and exposes it as a sensitive output
  api_key_create = true
}
```

For ready-to-deploy variants (single-region, EU/US multi-region, Open WebUI), see the [**samples repository**](https://github.com/stdapi-ai/samples). For deeper patterns (BYO VPC / ALB / Route 53 / S3, manual ECS, cost-optimized), see the [**advanced deployment guide**](https://stdapi.ai/operations_deploy_advanced/).

## License and Cost

stdapi.ai is dual-licensed: [**AGPL-3.0-or-later**](LICENSE-AGPL) for the free community container image, or a [**commercial license**](LICENSE-COMMERCIAL) obtained by subscribing on AWS Marketplace. **This module is commercial-only by construction** — it deploys the Marketplace ECR image, so an active Marketplace subscription is required. To run the AGPL community image instead, see the [local deployment guide](https://stdapi.ai/operations_getting_started_local/).

The Marketplace license is metered at **$0.10 per container-hour**, with a **14-day free trial** on the license. `autoscaling_min_capacity` defaults to one task per availability zone and `availability_zones_count` defaults to all AZs in the region, so a default deployment in a 3-AZ region runs 3 tasks — about **$216/month in license** (720 h × $0.10 × 3), and about $432/month in a 6-AZ region such as `us-east-1`. Set `availability_zones_count` and `autoscaling_min_capacity` explicitly to control this.

Only the license is covered by the trial. AWS resources this module creates (Fargate, ALB, NAT gateways, KMS, CloudWatch, S3) and Amazon Bedrock inference are billed by AWS from the first hour, with no markup. See the [cost management guide](https://stdapi.ai/operations_cost_management/) and the [licensing guide](https://stdapi.ai/operations_licensing/).

## Module Features

Production-ready infrastructure following AWS Well-Architected Framework:

- **🚀 Serverless Compute** — ECS Fargate with intelligent auto-scaling (0.25-16 vCPU, CPU/Memory/Request-based)
- **⚖️ Load Balancing** — Application Load Balancer with HTTPS/TLS, configurable idle timeout for long operations
- **🌐 Networking** — Dedicated VPC with private app subnets; AWS access via NAT gateways or interface VPC endpoints; optional public subnets for the ALB; IPv4/IPv6 support
- **🔒 Security** — WAF with rate limiting & IP filtering, KMS encryption, IAM roles with least privilege
- **📊 Monitoring** — Container Insights dashboards, optional CloudWatch alarms, VPC Flow Logs, request/response logging
- **💾 Storage** — S3 buckets with encryption, versioning, lifecycle policies, multi-region support
- **💰 Cost Optimization** — Fargate Spot support (~70% discount), scheduled auto-scaling, resource right-sizing

## Architecture

```
                        Internet
                           │  egress only when required (see table)
                ┌──────────▼──────────┐
                │   WAF    (optional) │   alb_waf_enabled
                └──────────┬──────────┘
                           │  inbound only when the ALB is enabled
                ┌──────────▼──────────┐
                │   ALB    (optional) │   alb_enabled / alb_public
                │   HTTPS / HTTP      │   (public subnets only if alb_public)
                └──────────┬──────────┘
                           │
   ┌───────────────────────┼───────────────────────┐
   │ VPC (dedicated, or bring-your-own subnet_ids) │
   │                       │                       │
   │            ┌──────────▼──────────┐  S3 gateway        ┌──────────────┐
   │            │     ECS Fargate     │  endpoint          │  S3 Bucket   │
   │            │   ┌─────────────┐   │  (always, free) ──▶│ (+ regional  │
   │            │   │  stdapi.ai  │   │                    │  buckets,    │
   │            │   │  Container  │   │                    │  KMS-encr.)  │
   │            │   └─────────────┘   │                    └──────────────┘
   │            │  app subnet (private)            │
   │            └──────────┬──────────┘            │
   │     egress to Bedrock, Polly, Transcribe, …   │
   │     uses exactly ONE of (mutually exclusive): │
   │       • NAT gateways            (default)     │
   │       • Interface VPC endpoints (no-internet) │
   └───────────────────────┬───────────────────────┘
                           │
                ┌──────────▼──────────┐
                │      CloudWatch     │
                └─────────────────────┘
```

### What gets provisioned, and when

| Component                                                                                                                                                                         | Created when                                                                                                                                                                                                                                                                                                                                                   |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Dedicated VPC, private app subnets, ECS Fargate service, KMS-encrypted S3 bucket(s), **S3 gateway endpoint**, CloudWatch logs                                                     | Always — except: passing your own `subnet_ids` skips VPC/subnet/endpoint creation entirely, and passing your own `aws_s3_bucket` skips bucket creation                                                                                                                                                                                                                                                              |
| **NAT gateways** (private internet egress)                                                                                                                                        | **Default.** Created whenever the app needs internet: AWS Marketplace auto-subscribe is on (`aws_bedrock_marketplace_auto_subscribe`, enabled unless explicitly set to `false`) **or** any AWS service runs outside the deployment region (e.g. multi-region `aws_bedrock_regions`). Set `nat_gateways_allowed = false` to instead make the app subnets public (cheaper, less isolated). |
| **Interface VPC endpoints** — Amazon Bedrock, Amazon Polly, Amazon Transcribe, Amazon Comprehend, Amazon Translate, CloudWatch Logs, SSM, ECR, Marketplace metering (Secrets Manager only with `api_key_secretsmanager_secret`) | Only when the app needs **no** internet egress: `aws_bedrock_marketplace_auto_subscribe = false` **and** every AWS service is in the deployment region **and** `vpc_endpoints_allowed = true` (default). Replaces the NAT path — the two are never created together.                                                                                           |
| Public subnets                                                                                                                                                                    | Only with a public ALB (`alb_enabled = true` **and** `alb_public = true`)                                                                                                                                                                                                                                                                                      |
| ALB + HTTPS listener / ACM certificate                                                                                                                                            | `alb_enabled = true` (HTTPS when `alb_domain_name` / `alb_certificate_arn` is set; auto ACM + Route 53 via `alb_domain_name`). Without an ALB the service is only reachable from inside the VPC.                                                                                                                                                                |
| WAF (rate limiting, IP filtering)                                                                                                                                                 | `alb_waf_enabled = true` (requires `alb_enabled`)                                                                                                                                                                                                                                                                                                              |
| API key authentication                                                                                                                                                            | One of `api_key_create`, `api_key`, `api_key_ssm_parameter`, `api_key_secretsmanager_secret`                                                                                                                                                                                                                                                                   |
| CloudWatch alarms (error/critical logs)                                                                                                                                           | `alarms_enabled = true`                                                                                                                                                                                                                                                                                                                                        |
| VPC Flow Logs                                                                                                                                                                     | `vpc_flow_log_enabled` (default `true`)                                                                                                                                                                                                                                                                                                                        |

## Examples & Integration

Ready-to-deploy Terraform examples live in the [**stdapi.ai samples repository**](https://github.com/stdapi-ai/samples):

| Example | What it deploys |
|---|---|
| [getting_started_production](https://github.com/stdapi-ai/samples/tree/main/getting_started_production) | Single-region production deployment with HTTPS, WAF, auto-scaling |
| [getting_started_production_gdpr](https://github.com/stdapi-ai/samples/tree/main/getting_started_production_gdpr) | Multi-region EU deployment (4 regions) for GDPR data residency |
| [getting_started_production_us](https://github.com/stdapi-ai/samples/tree/main/getting_started_production_us) | Multi-region US deployment (3 regions) for high availability |
| [getting_started_openwebui](https://github.com/stdapi-ai/samples/tree/main/getting_started_openwebui) | Full Open WebUI chat platform stack (Aurora + Valkey + SearXNG + stdapi.ai) |

For integration against existing infrastructure and non-Terraform deployments, see the [advanced deployment guide](https://stdapi.ai/operations_deploy_advanced/).

## Documentation

| Resource | Description |
|---|---|
| **[Getting Started](https://stdapi.ai/operations_getting_started/)** | Deployment examples and first API call |
| **[Advanced Deployment](https://stdapi.ai/operations_deploy_advanced/)** | VPC integration, multi-region, cost optimization |
| **[Configuration](https://stdapi.ai/operations_configuration/)** | All environment variables and module parameters |
| **[API Reference](https://stdapi.ai/api_overview/)** | OpenAI & Anthropic compatible API documentation |
| **[Use Cases](https://stdapi.ai/use_cases/)** | Open WebUI, n8n, coding assistants, and more |
| **[Features](https://stdapi.ai/features/)** | Full product capabilities |
| **[Cost Management](https://stdapi.ai/operations_cost_management/)** | License metering, AWS resource costs, and per-request cost estimation |
| **[Resilience & Failover](https://stdapi.ai/operations_resilience/)** | Multi-region routing, retry scope, and what does not fail over |
| **[Licensing](https://stdapi.ai/operations_licensing/)** | AGPL-3.0 community edition vs the Marketplace commercial license |
| **[Compliance](https://stdapi.ai/operations_compliance/)** | Data residency, region allow-lists, encryption, and outbound paths |
| **[IAM Permissions](https://stdapi.ai/operations_iam_permissions/)** | Deployment and task-role permissions required by this module |

## AWS Qualified Software

<div align="center">
<a href="https://aws.amazon.com/marketplace/pp/prodview-su2dajk5zawpo">
<img src="https://stdapi.ai/styles/aws_qualified_software_badge_light.png" alt="AWS Qualified Software badge" width="120" />
</a>

stdapi.ai is an **AWS Qualified Software** solution, verified against AWS technical and security requirements for AWS Marketplace.
</div>

## Security Hub Controls

Controls are grouped below by the deployment feature that gates them, not by which internal module implements them — the baseline section always applies; the rest only come into play once you enable the corresponding input. Only controls whose resolution is worth calling out are listed; N/A controls for resource types this module never creates (EFS, Classic Load Balancers, ECS task sets, Windows containers, Route 53 hosted zones/health checks) are omitted entirely.

Severity: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low

### Baseline (ECS Fargate, KMS keys, S3 buckets, IAM policies)

Always created, regardless of `subnet_ids`, `alb_enabled`, or any other toggle. Key inputs: `tags = local.apn_tags` (never null) is applied to every resource below, `cloudwatch_logs_retention_in_days` defaults `365`, the `main` container sets `read_only_root_filesystem = true` and `user = "65532:65532"`, secrets are passed via `secrets` never `environment`, and no `security_group_rules_ingress`/`security_group_connect_ingress` (internal wiring — not module variables) is passed (the only extra ingress rule references the ALB's security group, never a CIDR).

| Control | Severity | Title | Status | Notes |
|---|---|---|---|---|
| KMS.1 / KMS.2 | 🟡 Medium | IAM policies/inline policies should not allow decryption on all KMS keys | ✅ Pass | The application is only ever allowed to decrypt data using the specific encryption keys this deployment creates or is given — never every key in the account. |
| KMS.3 | 🔴 Critical | KMS keys should not be deleted unintentionally | ✅ Pass | No `deletion_window_in_days` override — AWS's 30-day maximum applies. |
| KMS.4 | 🟡 Medium | KMS key rotation should be enabled | ✅ Pass | Hardcoded for every key, including the per-Bedrock-region ones. |
| KMS.5 | 🔴 Critical | KMS keys should not be publicly accessible | ✅ Pass | Every policy statement scopes a specific AWS service principal with an `ArnLike`/`StringEquals` condition — none is a wildcard principal. |
| ECS.3 / ECS.4 / ECS.9 / ECS.10 / ECS.17 / ECS.18 | 🟠 High / 🟡 Medium | Various ECS controls (host PID namespace, non-privileged, logging config, Fargate platform version, host network mode, EFS in-transit encryption) | ✅ Pass | Unconditional defaults — not overridden. |
| ECS.14 | 🔵 Low | ECS clusters should be tagged | ✅ Pass | The cluster always receives a `Name` tag regardless of `tags`. |
| ECS.5 | 🟠 High | Task definitions should use read-only root filesystems | ✅ Pass | `read_only_root_filesystem = true` on the `main` container. |
| ECS.8 | 🟠 High | Secrets should not be passed as container environment variables | ✅ Pass | The API key is passed via `secrets`. |
| ECS.12 | 🟡 Medium | ECS clusters should use Container Insights | ✅ Pass | Defaults to `"enabled"`. |
| ECS.13 / ECS.15 | 🔵 Low | Service / task definition should be tagged | ✅ Pass | Non-null `tags` is applied directly, with no fallback. |
| ECS.20 | 🟡 Medium | Task definitions should configure non-root users for Linux containers | ✅ Pass | `user = "65532:65532"`, matching the Chainguard `python:latest` base image's actual default non-root user (`nonroot`, uid/gid 65532). |
| EC2.13 / EC2.14 / EC2.18 / EC2.53 / EC2.54 | 🟠 High | ECS service security group should not allow unrestricted/admin-port ingress | ✅ Pass | No CIDR-based ingress rule exists. |
| EC2.19 | 🔴 Critical | ECS service security group should not allow unrestricted access to high-risk ports | ✅ Pass | Same reasoning as above. |
| EC2.43 | 🔵 Low | ECS service security group should be tagged | ✅ Pass | Unconditional. |
| CloudWatch.16 | 🟡 Medium | CloudWatch log groups should be retained for a specified time period | ✅ Pass | `cloudwatch_logs_retention_in_days` defaults `365`, applied to every ECS log group including Container Insights. |
| CloudWatch.17 | 🟠 High | CloudWatch alarm actions should be activated | ✅ Pass | Unconditional whenever alarms exist (see **Other options** below). |
| IAM.1 | 🟠 High | IAM policies should not allow full "*" administrative privileges | ✅ Pass | The ECS execution/task role policies and the aggregated `aws_iam_policy.server` use no wildcard actions. |
| IAM.21 | 🔵 Low | IAM customer managed policies should not allow wildcard actions for services | ✅ Pass | Same statements as IAM.1 — no wildcard (`service:*`) actions. |
| S3.2 / S3.3 | 🔴 Critical | S3 buckets should block public read/write access | ✅ Pass | `aws_s3_bucket_public_access_block` sets all four flags to `true` for every bucket (main and regional). |
| S3.8 | 🟠 High | S3 buckets should block public access (account/bucket combined check) | ✅ Pass | Same configuration as S3.2/S3.3. |
| S3.5 | 🟡 Medium | S3 buckets should require requests to use SSL | ✅ Pass | Bucket policy denies all `s3:*` actions when `aws:SecureTransport` is false. |
| S3.6 | 🟠 High | S3 bucket policies should restrict access to other AWS accounts | ✅ Pass | The only statement is the TLS-enforcement `Deny`; no cross-account `Allow`. |
| S3.9 | 🟡 Medium | S3 buckets should have server access logging enabled | ⚠️ Pass on the data buckets, ❌ fail on the logs buckets | The main bucket logs to a shared SSE-S3-encrypted logs bucket (also used for ALB access logs); each regional bucket logs to its own per-Region logs bucket, since S3 access log destinations must stay in the source bucket's Region. The logs buckets themselves have no destination: pointing one at itself is refused by S3, and pointing two at each other makes each delivery generate another. |
| S3.10 / S3.13 | 🟡 Medium / 🔵 Low | S3 buckets should have lifecycle configurations | ✅ Pass | Every bucket gets an unconditional lifecycle configuration (tmp cleanup, files expiration, intelligent-tiering). |
| S3.11 | 🟡 Medium | S3 buckets should have event notifications enabled | ✅ Pass | `eventbridge = true` is set unconditionally — zero-config, no targets/rules required. |
| S3.12 | 🟡 Medium | ACLs should not be used to manage access to S3 buckets | ✅ Pass | New buckets default to `BucketOwnerEnforced` (ACLs disabled). |
| S3.14 | 🔵 Low | S3 buckets should have versioning enabled | ✅ Pass | `status = "Enabled"` unconditionally on every bucket. |
| S3.15 | 🟡 Medium | S3 buckets should have Object Lock enabled | ⬜ N/A | Object Lock (WORM immutability) doesn't fit this bucket's purpose — it's temporary storage with active expiration rules (1-day tmp cleanup, 30-day Files API expiration), the opposite of what Object Lock is for. |
| S3.17 | 🟡 Medium | S3 buckets should be encrypted at rest with AWS KMS keys | ⚠️ Pass on the data buckets, ❌ fail on the logs buckets | SSE-KMS with a dedicated customer-managed key, `bucket_key_enabled = true`. The logs buckets are SSE-S3: S3 server access logging and ALB access logging both refuse a customer-managed key as their destination, so this is the strongest encryption those buckets can carry. |
| S3.20 | 🔵 Low | S3 buckets should have MFA delete enabled | ⬜ N/A (exempt) | AWS's own control text exempts buckets with a lifecycle configuration — every bucket here always has one. |
| S3.22 / S3.23 | 🟡 Medium | S3 buckets should log object-level read/write events | ⬜ N/A | Account-level control requiring an org-wide multi-Region CloudTrail trail — outside this module's scope. |

Thanks to `tags` always being non-null, ECS.13/ECS.15 (tagged, above) actually **pass** — leaving `tags` unset would fail them; ECS.20 also passes thanks to the explicit `user`.

### Dedicated VPC (default; skipped entirely when you pass your own `subnet_ids`)

Key inputs: flow-log retention follows `cloudwatch_logs_retention_in_days` (default `365`); internet access is **enabled by default** (internal wiring — driven by `aws_bedrock_marketplace_auto_subscribe`, whose auto-subscribe default requires internet access for the AWS Marketplace API, and by any cross-region service usage); `nat_gateways_allowed` defaults `true`; the interface endpoint set (internal wiring — not a module variable) always includes `s3`, `ssm`, `logs`, `ecr.api`, `ecr.dkr`.

| Control | Severity | Title | Status | Notes |
|---|---|---|---|---|
| EC2.2 | 🟠 High | VPC default security groups should restrict all traffic | ✅ Pass | Unconditional. |
| EC2.6 | 🟡 Medium | VPC flow logging should be enabled in all VPCs | ✅ Pass | `vpc_flow_log_enabled` defaults `true`. |
| EC2.21 | 🟡 Medium | Network ACLs should not allow ingress from 0.0.0.0/0 to port 22/3389 | ❌ Fail (accepted) | The stateless network ACLs allow the ephemeral range for return traffic, which spans 3389. Unreachable: the security groups admit only 80/443 from the CIDRs you name, then only port 8000 from the load balancer. [Details](https://github.com/JGoutin/terraform-aws-vpc#why-ec221-fails). |
| EC2.53 / EC2.54 / EC2.13 / EC2.14 | 🟠 High | VPC default security group should not allow ingress from 0.0.0.0/0 to remote administration ports | ✅ Pass | Unconditional. |
| EC2.12 | 🔵 Low | Unused EIPs should be removed | ✅ Pass | Unconditional. |
| EC2.37 / EC2.39 / EC2.40 / EC2.41 / EC2.42 / EC2.43 / EC2.44 / EC2.46 / EC2.174 | 🔵 Low | Various VPC resources should be tagged | ✅ Pass | A `Name` tag is always merged in regardless of `tags`. |
| EC2.48 | 🔵 Low | VPC flow logs should be tagged | ✅ Pass | Non-null `tags` is applied directly, with no fallback. |
| IAM.24 | 🔵 Low | IAM roles should be tagged | ✅ Pass | Same reasoning as EC2.48, for the flow log's IAM role. |
| CloudWatch.16 | 🟡 Medium | CloudWatch log groups should be retained for a specified time period | ✅ Pass | Flow-log retention follows `cloudwatch_logs_retention_in_days` (default `365`). |

**Sub-variant — NAT gateways (default) vs. VPC interface endpoints (no internet egress)**

| Control | Severity | Title | Status | Notes |
|---|---|---|---|---|
| EC2.15 | 🟡 Medium | EC2 subnets should not automatically assign public IP addresses | ✅ Pass | No subnet assigns addresses on launch, in either architecture. With `nat_gateways_allowed = false` the app subnets become public, but the task still takes its address from `assign_public_ip` on its own network configuration rather than from the subnet. |
| ECS.2 | 🟠 High | Services should not have public IP addresses assigned automatically | ✅ Pass by default | Same trigger as EC2.15 — the ECS service only gets a public IP when `nat_gateways_allowed = false`. |

**Sub-variant — compliance VPC endpoints (`compliance_vpc_endpoints_enabled = true`)**

| Control | Severity | Title | Status | Notes |
|---|---|---|---|---|
| EC2.55 / EC2.56 / EC2.57 / EC2.58 / EC2.60 | 🟡 Medium | VPC should be configured with an interface endpoint for ECR API / Docker Registry / SSM / SSM Incident Manager Contacts / SSM Incident Manager | ⚠️ Conditional (default: ❌ Fail) | The endpoint set (internal wiring `vpc_endpoints_services`) already requests `ecr.api`/`ecr.dkr`/`ssm`, but that only takes effect when there's no direct internet route — and by default there is one. Set `compliance_vpc_endpoints_enabled = true` to force these 5 endpoints regardless of internet posture. |

Thanks to `tags` always being non-null, EC2.48 and IAM.24 (tagged, above) actually **pass** — leaving `tags` unset would fail them. One gap remains at default settings: **EC2.55/56/57/58/60** are silently ineffective, because internet access is required for AWS Marketplace auto-subscribe — set `compliance_vpc_endpoints_enabled = true` to close it.

### Public/HTTPS ALB (`alb_enabled = true`)

| Control | Severity | Title | Status | Notes |
|---|---|---|---|---|
| ELB.1 | 🟡 Medium | ALB should redirect all HTTP requests to HTTPS | ⚠️ Conditional (default: ❌ Fail) | The HTTP listener only redirects when a certificate exists. Set `alb_certificate_arn` or `alb_domain_name` (with a resolvable Route 53 zone) to get a certificate and enable the redirect. |
| ELB.4 | 🟡 Medium | ALB should be configured to drop invalid HTTP headers | ✅ Pass | `drop_invalid_header_fields = true` is hardcoded. |
| ELB.5 | 🟡 Medium | ALB should have logging enabled | ⚠️ Conditional (default: ✅ Pass) | `alb_access_logging_enabled` defaults `true` — a dedicated SSE-S3-encrypted bucket is created and wired to the load balancer's `access_logs` block. |
| ELB.6 | 🟡 Medium | ALB should have deletion protection enabled | ⚠️ Conditional (default: ❌ Fail) | Set `deletion_protection = true` (default `false`). |
| ELB.12 | 🟡 Medium | ALB should use defensive or strictest desync mitigation mode | ✅ Pass | Not set explicitly, but AWS's own default (`defensive`) satisfies the control. |
| ELB.13 | 🟡 Medium | ALB should span multiple Availability Zones | ⚠️ Conditional (default: ✅ Pass) | Subnets use all available AZs by default (`availability_zones_count = null`) — always ≥2 in practice. Fails only if `availability_zones_count` is explicitly set to `1`. |
| ELB.17 | 🟡 Medium | ALB listeners should use recommended security policies | ⚠️ Conditional (default: ✅ Pass once HTTPS exists, N/A otherwise) | `alb_ssl_policy` defaults to `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09`, one of AWS's recommended policies. Only applies once the HTTPS listener exists (see ELB.1). |
| ELB.18 | 🟡 Medium | ALB listeners should be configured with a secure listener protocol | ❌ Fail | The HTTP listener (port 80) always exists; there's no exemption for a redirect-only listener. Inherent to offering both HTTP and HTTPS. |
| ELB.21 | 🟡 Medium | ELB target groups should have health check configured with encrypted protocol | ❌ Fail | The health check uses the default `HTTP` protocol; no variable exposes HTTPS health checks. Requires a code change to pass. |
| ELB.22 | 🟡 Medium | ELB target groups should use encrypted transport protocol | ❌ Fail | The target group forwards to the ECS task over plain `HTTP` on the container port (TLS terminates at the ALB, not re-established to the backend). Requires a code change to pass. |
| ACM.1 | 🟡 Medium | ACM certificates should be renewed after a specified time period | ✅ Pass | DNS validation (`validation_method = "DNS"`), which ACM renews automatically. |
| ACM.2 | 🟠 High | RSA certificates managed by ACM should use a key length of at least 2,048 bits | ✅ Pass | `key_algorithm` isn't set, so ACM uses its default `RSA_2048`. |
| ACM.3 | 🔵 Low | ACM certificates should be tagged | ✅ Pass | Tagged via non-null `tags` plus a `Name` tag. |

**Sub-variant — WAF (`alb_waf_enabled = true`, requires `alb_enabled = true`)**

| Control | Severity | Title | Status | Notes |
|---|---|---|---|---|
| ELB.16 | 🟡 Medium | ALB should be associated with a WAF web ACL | ⚠️ Conditional (default: ❌ Fail) | Set `alb_waf_enabled = true` to pass. |
| WAFV2.1 (AWS WAF `WAF.10`) | 🟡 Medium | AWS WAF web ACLs should have at least one rule or rule group | ✅ Pass once enabled | Three AWS managed rule groups are always attached — never empty. |
| WAFV2.2 (AWS WAF `WAF.11`) | 🔵 Low | AWS WAF web ACL logging should be enabled | ✅ Pass once enabled | `alb_waf_logging_enabled` defaults `true`. |

With `alb_enabled = false` (default), none of the ALB/WAF/ACM controls above apply — no load balancer exists. Once enabled, ELB.4 and ELB.5 pass out of the box. ELB.18, ELB.21, ELB.22 fail **unconditionally** — closing them requires re-architecting to terminate TLS on the backend, not just adding a variable — while ELB.1, ELB.6, ELB.16 fail **by default** until their respective variables are set.

**Client IP trust (`X-Forwarded-For`)** — not a Security Hub control, but a hardening applied automatically for ALB deployments. When the ALB is enabled together with `log_client_ip = true`, the module enables `ENABLE_PROXY_HEADERS` so the real client IP (not the ALB's) is recorded in request logs and OpenTelemetry spans. To keep that value trustworthy, it also pins `PROXY_TRUSTED_HOSTS` to the ALB's own subnet CIDRs (IPv4 and IPv6): the server honors `X-Forwarded-*` only when the immediate peer is the ALB. Because an ALB **appends** to `X-Forwarded-For` rather than replacing it, without this restriction a client could prepend a forged entry and poison the recorded client IP; pinning the trust to the ALB subnets makes the real appended address authoritative instead. This is defense in depth on top of the ECS security group, which already allows ingress only from the ALB's security group. Set `proxy_trusted_hosts` explicitly to override — for example when fronting the ALB with an additional proxy such as CloudFront, set it to that proxy's egress range.

### Other options

Independent toggles that don't gate other controls and aren't required to pass any control above.

**CloudWatch Alarms** (`alarms_enabled = true`, notifications sent to `sns_topic_arn`)

| Control | Severity | Title | Status | Notes |
|---|---|---|---|---|
| CloudWatch.15 | 🟠 High | CloudWatch alarms should have specified actions configured | ⚠️ Conditional (default: N/A — no alarms) | `alarms_enabled` defaults `false`. Set `alarms_enabled = true` and `sns_topic_arn` to pass. |

Enabling it creates five alarms:
- **High memory usage** — ECS service `MemoryUtilization` > 90% for 4 of 5 one-minute periods.
- **Unhealthy containers** — ECS service `HealthCheckFailed` > 0.
- **CPU anomaly detection** — CloudWatch anomaly-detection band around `CPUUtilization`; fires when usage exceeds the expected upper bound.
- **Max autoscaling capacity reached** — Container Insights `DesiredTaskCount` >= `autoscaling_max_capacity` (only created if min/max capacity differ and Container Insights is enabled).
- **Application error/critical logs** — a log metric filter counts `error`/`ERROR`/`critical`/`CRITICAL` matches in the app's CloudWatch log group; fires when any appear within a 60-second period.

The four ECS-level alarms require `sns_topic_arn` to be set (they always attach it as an action); the log-based alarm tolerates a null `sns_topic_arn` and simply exists without notifying anyone.

**Amazon GuardDuty Runtime Monitoring endpoint** (`guardduty_vpc_endpoint_enabled = true`, dedicated VPC only) — not a Security Hub control. Enforced regardless of internet posture.

**Route 53 Resolver DNS Firewall** (`dns_firewall_enabled = true`, dedicated VPC only) — not a Security Hub control. Blocks/alerts on DNS queries to known-malicious domains (AWS Managed Domain Lists, plus DGA/DNS-tunneling detection via `dns_firewall_advanced_enabled`). Complements application-level SSRF protection against malicious-URL injection through user-supplied URL/file reference fields. Has no effect (and cannot be enabled) when `subnet_ids` is set.

All the options above are off by default and never required to pass a control in the sections higher up.

---

# Terraform Documentation

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.27.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.27.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_kms_key"></a> [kms\_key](#module\_kms\_key) | JGoutin/kms-key/aws | ~> 1.2 |
| <a name="module_regional_kms"></a> [regional\_kms](#module\_regional\_kms) | JGoutin/kms-key/aws | ~> 1.2 |
| <a name="module_server"></a> [server](#module\_server) | JGoutin/ecs-fargate/aws | ~> 1.3 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | JGoutin/vpc/aws | ~> 1.3 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_acm_certificate.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
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
| [aws_s3_bucket.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.regional_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.regional_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_logging.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_notification.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_s3_bucket_notification.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_s3_bucket_policy.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.regional_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.regional_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.regional_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.regional_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
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
| [aws_iam_policy_document.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.main_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.regional_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.regional_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.by_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_s3_bucket.user_provided](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_ai_response_timeout"></a> [ai\_response\_timeout](#input\_ai\_response\_timeout) | Maximum time in seconds to wait for an AI model to complete a response. Applies to both streaming and non-streaming requests. The default of 600 seconds accommodates models with extended reasoning. Increase for long-running requests (e.g., large document analysis); decrease to fail fast on unexpectedly slow responses. Default to 600. | `number` | `null` | no |
| <a name="input_alarms_enabled"></a> [alarms\_enabled](#input\_alarms\_enabled) | Enable CloudWatch alarms. This should be set to true if sns\_topic\_arn is provided. | `bool` | `false` | no |
| <a name="input_alb_access_logging_enabled"></a> [alb\_access\_logging\_enabled](#input\_alb\_access\_logging\_enabled) | If true, enable ALB access logging to a dedicated S3 bucket. Security Hub: ELB.5 (Application Load Balancers should have logging enabled) — default true = pass; only relevant when var.alb\_enabled is true. | `bool` | `true` | no |
| <a name="input_alb_certificate_arn"></a> [alb\_certificate\_arn](#input\_alb\_certificate\_arn) | Existing ACM certificate ARN to attach to the HTTPS listener. When specified, takes precedence over certificate\_create. If not specified and certificate\_create is true, a certificate will be created automatically. | `string` | `null` | no |
| <a name="input_alb_certificate_create"></a> [alb\_certificate\_create](#input\_alb\_certificate\_create) | If true, create an ACM certificate and validate it via DNS. Only used when certificate\_arn is not specified. Requires route53\_zone\_id, domain\_name, and route53\_zone\_private=false. | `bool` | `true` | no |
| <a name="input_alb_domain_name"></a> [alb\_domain\_name](#input\_alb\_domain\_name) | Primary domain name for the application (e.g., api.example.com). Creates Route 53 A record and ACM certificate. If route53\_zone\_id is not specified, automatically looks up the most specific parent domain zone. | `string` | `null` | no |
| <a name="input_alb_enabled"></a> [alb\_enabled](#input\_alb\_enabled) | If true, create an Application Load Balancer for the ECS service. Cannot be used with external subnets (subnet\_ids). | `bool` | `false` | no |
| <a name="input_alb_idle_timeout"></a> [alb\_idle\_timeout](#input\_alb\_idle\_timeout) | The time in seconds that the connection is allowed to be idle. Range: 1-4000 seconds. Default to 3600 (1 hour) to support slow LLM responses and long-running operations like AWS Transcribe. | `number` | `3600` | no |
| <a name="input_alb_ingress_ipv4_cidrs"></a> [alb\_ingress\_ipv4\_cidrs](#input\_alb\_ingress\_ipv4\_cidrs) | List of IPv4 CIDR blocks allowed to access the ALB. Default to ['0.0.0.0/0'] for public access. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_alb_ingress_ipv6_cidrs"></a> [alb\_ingress\_ipv6\_cidrs](#input\_alb\_ingress\_ipv6\_cidrs) | List of IPv6 CIDR blocks allowed to access the ALB. Default to ['::/0'] for public access. | `list(string)` | <pre>[<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_alb_public"></a> [alb\_public](#input\_alb\_public) | If true, create a public (internet-facing) ALB with dedicated public subnets. If false, create a private (internal) ALB using app subnets. | `bool` | `false` | no |
| <a name="input_alb_route53_zone_id"></a> [alb\_route53\_zone\_id](#input\_alb\_route53\_zone\_id) | Route 53 hosted zone ID for DNS records. If not specified, automatically infers the zone from the parent domain of domain\_name (e.g., 'api.example.com' → 'example.com', 'api.sandbox.example.com' → 'sandbox.example.com'). | `string` | `null` | no |
| <a name="input_alb_route53_zone_name"></a> [alb\_route53\_zone\_name](#input\_alb\_route53\_zone\_name) | Route 53 hosted zone name for DNS records (e.g., 'example.com'). Alternative to route53\_zone\_id - module will look up the zone ID automatically. If specified with domain\_name, creates DNS records and ACM certificate. | `string` | `null` | no |
| <a name="input_alb_route53_zone_private"></a> [alb\_route53\_zone\_private](#input\_alb\_route53\_zone\_private) | If true, the Route 53 zone is private. If false, it's public. Used when looking up the zone by name. | `bool` | `false` | no |
| <a name="input_alb_ssl_policy"></a> [alb\_ssl\_policy](#input\_alb\_ssl\_policy) | SSL/TLS security policy for the ALB HTTPS listener. Defaults to the AWS-recommended post-quantum policy. See https://docs.aws.amazon.com/elasticloadbalancing/latest/application/describe-ssl-policies.html | `string` | `"ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"` | no |
| <a name="input_alb_waf_block_anonymous_ips"></a> [alb\_waf\_block\_anonymous\_ips](#input\_alb\_waf\_block\_anonymous\_ips) | If true, block requests from anonymous IP addresses (VPNs, proxies, Tor exit nodes). | `bool` | `false` | no |
| <a name="input_alb_waf_enabled"></a> [alb\_waf\_enabled](#input\_alb\_waf\_enabled) | If true, create a WAF WebACL and associate it with the ALB (requires alb\_enabled=true). | `bool` | `false` | no |
| <a name="input_alb_waf_logging_enabled"></a> [alb\_waf\_logging\_enabled](#input\_alb\_waf\_logging\_enabled) | If true, enable WAF logging to CloudWatch Logs. | `bool` | `true` | no |
| <a name="input_alb_waf_rate_limit"></a> [alb\_waf\_rate\_limit](#input\_alb\_waf\_rate\_limit) | Maximum number of requests allowed from a single IP address in a 5-minute period. If null, rate limiting is disabled. | `number` | `null` | no |
| <a name="input_anthropic_beta_allowlist"></a> [anthropic\_beta\_allowlist](#input\_anthropic\_beta\_allowlist) | Additional anthropic\_beta flags to allow beyond the built-in defaults. Comma-separated string. Merged with the built-in set of Bedrock-supported flags. Only effective when anthropic\_beta\_filter is true. | `string` | `null` | no |
| <a name="input_anthropic_beta_filter"></a> [anthropic\_beta\_filter](#input\_anthropic\_beta\_filter) | Enable filtering of unsupported anthropic\_beta flags for Anthropic Claude models. When enabled, flags not in the allowlist are silently removed to prevent Bedrock ValidationException errors. Default to true. | `bool` | `null` | no |
| <a name="input_anthropic_routes_prefix"></a> [anthropic\_routes\_prefix](#input\_anthropic\_routes\_prefix) | Anthropic API compatible routes prefix. Default to '/anthropic'. | `string` | `null` | no |
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
| <a name="input_aws_adaptive_retry"></a> [aws\_adaptive\_retry](#input\_aws\_adaptive\_retry) | Enable adaptive retry mode for all AWS service calls. When enabled, the client dynamically adjusts its retry behavior based on observed error rates, slowing down when a service appears congested. Default to false. | `bool` | `null` | no |
| <a name="input_aws_bedrock_allow_application_inference_profile_arn"></a> [aws\_bedrock\_allow\_application\_inference\_profile\_arn](#input\_aws\_bedrock\_allow\_application\_inference\_profile\_arn) | If True, allow users to pass application inference profile ARNs directly as model IDs. Application inference profiles are custom routing configurations for specific use cases. When disabled, only standard model IDs and configured profiles are accepted. | `bool` | `null` | no |
| <a name="input_aws_bedrock_allow_cross_region_inference_profile_arn"></a> [aws\_bedrock\_allow\_cross\_region\_inference\_profile\_arn](#input\_aws\_bedrock\_allow\_cross\_region\_inference\_profile\_arn) | If True, allow users to pass cross-region inference profile ARNs directly as model IDs. Cross-region inference profiles enable routing to multiple regions for better availability. When disabled, only standard model IDs and configured profiles are accepted. | `bool` | `null` | no |
| <a name="input_aws_bedrock_allow_guardrail_override"></a> [aws\_bedrock\_allow\_guardrail\_override](#input\_aws\_bedrock\_allow\_guardrail\_override) | Allow users to override the global guardrail configuration at request level using headers (X-Amzn-Bedrock-GuardrailIdentifier, X-Amzn-Bedrock-GuardrailVersion, X-Amzn-Bedrock-Trace). When disabled and a global guardrail is configured, request headers are ignored for security. Defaults to false for security. | `bool` | `null` | no |
| <a name="input_aws_bedrock_allow_mantle_project_override"></a> [aws\_bedrock\_allow\_mantle\_project\_override](#input\_aws\_bedrock\_allow\_mantle\_project\_override) | If true, allow clients to override the configured Amazon Bedrock Mantle project per request via the 'OpenAI-Project' / 'anthropic-workspace' header. Default to false. | `bool` | `null` | no |
| <a name="input_aws_bedrock_allow_prompt_router_arn"></a> [aws\_bedrock\_allow\_prompt\_router\_arn](#input\_aws\_bedrock\_allow\_prompt\_router\_arn) | If True, allow users to pass prompt router ARNs directly as model IDs. Prompt routers enable dynamic model selection based on prompt characteristics. When disabled, only standard model IDs and configured profiles are accepted. | `bool` | `null` | no |
| <a name="input_aws_bedrock_cross_region_inference"></a> [aws\_bedrock\_cross\_region\_inference](#input\_aws\_bedrock\_cross\_region\_inference) | If true, allow cross region inference to be used. Default to true. | `bool` | `null` | no |
| <a name="input_aws_bedrock_cross_region_inference_global"></a> [aws\_bedrock\_cross\_region\_inference\_global](#input\_aws\_bedrock\_cross\_region\_inference\_global) | If True, allow 'global' cross region inference that can route requests to any region, worldwide. Default to true. | `bool` | `null` | no |
| <a name="input_aws_bedrock_deprecated_model_fallback"></a> [aws\_bedrock\_deprecated\_model\_fallback](#input\_aws\_bedrock\_deprecated\_model\_fallback) | If true, requests that use a deprecated model ID are transparently retried with the recommended replacement model instead of returning a 404 error. Disable if you want deprecated model IDs to fail explicitly so clients are forced to migrate. Default to true. | `bool` | `null` | no |
| <a name="input_aws_bedrock_deprecated_models"></a> [aws\_bedrock\_deprecated\_models](#input\_aws\_bedrock\_deprecated\_models) | Additional deprecated model ID mappings, merged with the built-in deprecation registry at startup. User-provided entries take precedence over built-in ones.<br/><br/>Keys are deprecated model IDs, values are the recommended replacement model IDs.<br/><br/>Example: { "my-old-model-v1" = "my-new-model-v2" } | `map(string)` | `null` | no |
| <a name="input_aws_bedrock_guardrail_identifier"></a> [aws\_bedrock\_guardrail\_identifier](#input\_aws\_bedrock\_guardrail\_identifier) | Amazon Bedrock Guardrails ID. | `string` | `null` | no |
| <a name="input_aws_bedrock_guardrail_trace"></a> [aws\_bedrock\_guardrail\_trace](#input\_aws\_bedrock\_guardrail\_trace) | Amazon Bedrock Guardrails trace setting: disabled, enabled, or enabled\_full. | `string` | `null` | no |
| <a name="input_aws_bedrock_guardrail_version"></a> [aws\_bedrock\_guardrail\_version](#input\_aws\_bedrock\_guardrail\_version) | Amazon Bedrock Guardrails version. | `string` | `null` | no |
| <a name="input_aws_bedrock_legacy"></a> [aws\_bedrock\_legacy](#input\_aws\_bedrock\_legacy) | If true, allow legacy Bedrock models to be used. Default to false. | `bool` | `null` | no |
| <a name="input_aws_bedrock_mantle_enabled"></a> [aws\_bedrock\_mantle\_enabled](#input\_aws\_bedrock\_mantle\_enabled) | If true (application default), expose models served by the Amazon Bedrock Mantle endpoint (OpenAI GPT, xAI Grok, Google Gemma, and more) in addition to the classic Bedrock Converse models. Set to false to disable Mantle. When enabled but Mantle is unreachable or the region lacks the service, Mantle models are simply not listed. | `bool` | `null` | no |
| <a name="input_aws_bedrock_mantle_preferred_models"></a> [aws\_bedrock\_mantle\_preferred\_models](#input\_aws\_bedrock\_mantle\_preferred\_models) | Model IDs (or ID prefixes) served by Amazon Bedrock Mantle even when also available on the classic bedrock-runtime endpoint. Default to none (bedrock-runtime preferred). | `list(string)` | `null` | no |
| <a name="input_aws_bedrock_mantle_project"></a> [aws\_bedrock\_mantle\_project](#input\_aws\_bedrock\_mantle\_project) | Default Amazon Bedrock Mantle project (workspace) ID used to attribute Mantle inference requests for cost tracking and observability. A bare project ID such as 'proj\_abc123' or 'default' (not an ARN). Default to none. | `string` | `null` | no |
| <a name="input_aws_bedrock_mantle_regions"></a> [aws\_bedrock\_mantle\_regions](#input\_aws\_bedrock\_mantle\_regions) | List of AWS regions used for Amazon Bedrock Mantle, in failover priority order. Default to var.aws\_bedrock\_regions. | `list(string)` | `null` | no |
| <a name="input_aws_bedrock_mantle_service_header"></a> [aws\_bedrock\_mantle\_service\_header](#input\_aws\_bedrock\_mantle\_service\_header) | If true, honor the 'x-stdapi-service: bedrock-mantle' request header to route a dual-homed model through Bedrock Mantle for that request. Cannot be combined with Bedrock Guardrails. Default to false. | `bool` | `null` | no |
| <a name="input_aws_bedrock_marketplace_auto_subscribe"></a> [aws\_bedrock\_marketplace\_auto\_subscribe](#input\_aws\_bedrock\_marketplace\_auto\_subscribe) | If true, allow the server to automatically subscribe to new models in the AWS Marketplace. Default to true. | `bool` | `null` | no |
| <a name="input_aws_bedrock_max_retries"></a> [aws\_bedrock\_max\_retries](#input\_aws\_bedrock\_max\_retries) | Maximum number of retries for Bedrock invocations. When region routing is enabled, retries cycle through all available regions. Default to 9. | `number` | `null` | no |
| <a name="input_aws_bedrock_model_arn_mapping"></a> [aws\_bedrock\_model\_arn\_mapping](#input\_aws\_bedrock\_model\_arn\_mapping) | Map standard model IDs to custom inference profile or prompt router ARNs. This allows server administrators to override the default cross-region inference profiles with custom application inference profiles, cross-region inference profiles, or prompt routers.<br/><br/>Supported ARN types:<br/>- Cross-region inference profile: arn:aws:bedrock:REGION:ACCOUNT:inference-profile/ID<br/>- Application inference profile: arn:aws:bedrock:REGION:ACCOUNT:application-inference-profile/ID<br/>- Prompt router: arn:aws:bedrock:REGION:ACCOUNT:default-prompt-router/ID<br/><br/>Example: {<br/>  "anthropic.claude-3-5-sonnet-20241022-v2:0" = "arn:aws:bedrock:us-east-1:123456789012:application-inference-profile/my-custom-profile"<br/>  "anthropic.claude-haiku-4-5-20251001-v1:0" = "arn:aws:bedrock:us-east-1:123456789012:default-prompt-router/my-router"<br/>} | `map(string)` | `null` | no |
| <a name="input_aws_bedrock_model_region_restrict"></a> [aws\_bedrock\_model\_region\_restrict](#input\_aws\_bedrock\_model\_region\_restrict) | Restrict a model to specific region(s) only. Can be used when a model provides important features only in certain regions.<br/><br/>Keys are Bedrock model IDs (or prefixes), values are ordered lists of allowed regions. When set, the model will only be available in the listed regions (intersected with the regions where it is actually available).<br/><br/>Example: { "amazon.nova-pro-v1:0" = ["us-east-1"] }<br/><br/>Use case: Nova grounding is only available in us-east-1, so restricting nova-pro to us-east-1 ensures grounding always works. | `map(list(string))` | `null` | no |
| <a name="input_aws_bedrock_region_routing"></a> [aws\_bedrock\_region\_routing](#input\_aws\_bedrock\_region\_routing) | Automatic region routing strategy for Bedrock invocations. Distributes requests across configured regions to handle quota limits and regional unavailability. Strategies: 'disabled' (no routing), 'ordered' (try regions in configured order, default), 'lowest\_latency' (prefer region with lowest measured latency), 'round\_robin' (distribute evenly, incompatible with prompt caching). Requires at least 2 regions in aws\_bedrock\_regions. | `string` | `null` | no |
| <a name="input_aws_bedrock_region_routing_max_quota_backoff_seconds"></a> [aws\_bedrock\_region\_routing\_max\_quota\_backoff\_seconds](#input\_aws\_bedrock\_region\_routing\_max\_quota\_backoff\_seconds) | Hard ceiling in seconds on the exponential quota backoff for a single region. Quota backoff doubles on each consecutive error; this value caps how high it can grow. Only effective when aws\_bedrock\_region\_routing is not 'disabled'. Default to 3600 (1 hour). | `number` | `null` | no |
| <a name="input_aws_bedrock_region_routing_quota_backoff_seconds"></a> [aws\_bedrock\_region\_routing\_quota\_backoff\_seconds](#input\_aws\_bedrock\_region\_routing\_quota\_backoff\_seconds) | Seconds to avoid a region after receiving a quota/throttling error. Only effective when aws\_bedrock\_region\_routing is not 'disabled'. Default to 60. | `number` | `null` | no |
| <a name="input_aws_bedrock_region_routing_quota_stale_factor"></a> [aws\_bedrock\_region\_routing\_quota\_stale\_factor](#input\_aws\_bedrock\_region\_routing\_quota\_stale\_factor) | Multiplier applied to the max quota backoff to compute the stale-error threshold. If the most recent quota error for a region is older than (max\_quota\_backoff * factor) seconds, the consecutive-error counter is reset. Only effective when aws\_bedrock\_region\_routing is not 'disabled'. Default to 2. | `number` | `null` | no |
| <a name="input_aws_bedrock_region_routing_unavailable_backoff_seconds"></a> [aws\_bedrock\_region\_routing\_unavailable\_backoff\_seconds](#input\_aws\_bedrock\_region\_routing\_unavailable\_backoff\_seconds) | Seconds to avoid a region after receiving an unavailability error. Only effective when aws\_bedrock\_region\_routing is not 'disabled'. Default to 30. | `number` | `null` | no |
| <a name="input_aws_bedrock_regions"></a> [aws\_bedrock\_regions](#input\_aws\_bedrock\_regions) | List of AWS regions where Bedrock AI models are available. Default to the current region. | `list(string)` | `null` | no |
| <a name="input_aws_bedrock_session_encryption_key_arn"></a> [aws\_bedrock\_session\_encryption\_key\_arn](#input\_aws\_bedrock\_session\_encryption\_key\_arn) | KMS key ARN encrypting the AWS Bedrock sessions that back stored responses and chat completions (store=true). Default to the AWS-managed key. | `string` | `null` | no |
| <a name="input_aws_comprehend_region"></a> [aws\_comprehend\_region](#input\_aws\_comprehend\_region) | AWS region for Comprehend language detection service. Default to every var.aws\_bedrock\_regions region as a failover candidate, or the current region. | `string` | `null` | no |
| <a name="input_aws_connect_timeout"></a> [aws\_connect\_timeout](#input\_aws\_connect\_timeout) | Timeout in seconds for establishing a connection to an AWS service endpoint. Keeping this value short allows fast failover to another region when a connection cannot be established. Default to 5. | `number` | `null` | no |
| <a name="input_aws_failover_max_retries"></a> [aws\_failover\_max\_retries](#input\_aws\_failover\_max\_retries) | Maximum SDK retry attempts per candidate region for the multi-region failover services (Polly, Transcribe, Translate, Comprehend). Only applied when the service has several candidate regions (no dedicated region setting configured). Default to 2. | `number` | `null` | no |
| <a name="input_aws_max_pool_connections"></a> [aws\_max\_pool\_connections](#input\_aws\_max\_pool\_connections) | Maximum number of concurrent HTTP connections per AWS service client. Each AWS service client (per region) maintains its own connection pool up to this limit. Increase if you observe connection pool exhaustion under high concurrency. Default to 50. | `number` | `null` | no |
| <a name="input_aws_polly_region"></a> [aws\_polly\_region](#input\_aws\_polly\_region) | AWS region for Polly text-to-speech service. Default to every var.aws\_bedrock\_regions region as a failover candidate, or the current region. | `string` | `null` | no |
| <a name="input_aws_s3_accelerate"></a> [aws\_s3\_accelerate](#input\_aws\_s3\_accelerate) | Enable S3 Transfer Acceleration for presigned URLs. Default to false. | `bool` | `null` | no |
| <a name="input_aws_s3_accepted_buckets"></a> [aws\_s3\_accepted\_buckets](#input\_aws\_s3\_accepted\_buckets) | S3 buckets that the application has read access to, mapped to their region. These buckets can be used as input S3 data sources, and S3 HTTP URLs (including presigned URLs) for these buckets will be automatically converted to S3 URIs for direct access.<br/><br/>Keys are bucket names, values are AWS region identifiers.<br/><br/>Example: { "my-data-bucket" = "us-east-1", "my-eu-bucket" = "eu-west-1" }<br/><br/>If not specified, only the application's own S3 buckets (aws\_s3\_bucket and aws\_s3\_regional\_buckets) are recognized for S3 URI conversion. | `map(string)` | `null` | no |
| <a name="input_aws_s3_accepted_buckets_kms_key_arn"></a> [aws\_s3\_accepted\_buckets\_kms\_key\_arn](#input\_aws\_s3\_accepted\_buckets\_kms\_key\_arn) | List of KMS key ARNs used to encrypt the accepted S3 buckets (var.aws\_s3\_accepted\_buckets). Required to grant the server permissions to decrypt objects from KMS-encrypted accepted buckets. | `list(string)` | `null` | no |
| <a name="input_aws_s3_bucket"></a> [aws\_s3\_bucket](#input\_aws\_s3\_bucket) | Existing S3 bucket name for storing generated files and application data. When specified, takes precedence over aws\_s3\_bucket\_create. If not specified and aws\_s3\_bucket\_create is true, a bucket will be created automatically. | `string` | `null` | no |
| <a name="input_aws_s3_bucket_create"></a> [aws\_s3\_bucket\_create](#input\_aws\_s3\_bucket\_create) | If true, create an S3 bucket for the application. Only used when aws\_s3\_bucket is not specified. When aws\_s3\_bucket is specified, this value is ignored. | `bool` | `true` | no |
| <a name="input_aws_s3_buckets_kms_keys_arns"></a> [aws\_s3\_buckets\_kms\_keys\_arns](#input\_aws\_s3\_buckets\_kms\_keys\_arns) | List of KMS key ARNs used to encrypt user-provided regional S3 buckets specified in `aws_s3_regional_buckets`.<br/>Required to grant the server permissions to access encrypted regional buckets.<br/>When using `aws_s3_regional_buckets_create = true` (default), KMS keys are created automatically and do not need to be specified here. | `list(string)` | `[]` | no |
| <a name="input_aws_s3_files_prefix"></a> [aws\_s3\_files\_prefix](#input\_aws\_s3\_files\_prefix) | S3 prefix (folder path) for Files API objects. Default to 'files/'. | `string` | `null` | no |
| <a name="input_aws_s3_regional_buckets"></a> [aws\_s3\_regional\_buckets](#input\_aws\_s3\_regional\_buckets) | By default (`aws_s3_regional_buckets_create = true`), buckets are created automatically for every region in `aws_bedrock_regions` not listed here. Use this variable only to point to **existing** buckets you manage yourself.<br/><br/>Keys are AWS region identifiers, values are bucket names.<br/><br/>Example: { "us-east-1" = "my-bucket-us-east-1", "us-west-2" = "my-bucket-us-west-2" }<br/><br/>Required for Bedrock operations with multimodal input or document processing. | `map(string)` | `null` | no |
| <a name="input_aws_s3_regional_buckets_create"></a> [aws\_s3\_regional\_buckets\_create](#input\_aws\_s3\_regional\_buckets\_create) | If true (default), create regional S3 buckets and per-region KMS keys for every region in `aws_bedrock_regions`<br/>not already present as a key of `aws_s3_regional_buckets` and not equal to the provider's primary region.<br/><br/>Set to false to disable automatic creation (for example, if you manage these buckets out-of-band). | `bool` | `true` | no |
| <a name="input_aws_s3_tmp_prefix"></a> [aws\_s3\_tmp\_prefix](#input\_aws\_s3\_tmp\_prefix) | S3 prefix (folder path) for temporary files used during job processing. Default to 'tmp/'. | `string` | `null` | no |
| <a name="input_aws_s3_videos_expires_after"></a> [aws\_s3\_videos\_expires\_after](#input\_aws\_s3\_videos\_expires\_after) | Retention period in seconds for generated videos. When set, Video.expires\_at is reported, expired downloads return 404, and a matching S3 Lifecycle expiration rule is created on the module-managed buckets. Default to no expiry. | `number` | `null` | no |
| <a name="input_aws_s3_videos_prefix"></a> [aws\_s3\_videos\_prefix](#input\_aws\_s3\_videos\_prefix) | S3 prefix (folder path) for videos generated through the Videos API. Default to 'videos/'. | `string` | `null` | no |
| <a name="input_aws_transcribe_region"></a> [aws\_transcribe\_region](#input\_aws\_transcribe\_region) | AWS region for Transcribe speech-to-text service. Default to every var.aws\_bedrock\_regions region as a failover candidate, or the current region. | `string` | `null` | no |
| <a name="input_aws_transcribe_s3_bucket"></a> [aws\_transcribe\_s3\_bucket](#input\_aws\_transcribe\_s3\_bucket) | AWS S3 bucket name for temporary file storage during transcription. Defaults to aws\_s3\_bucket if not specified. | `string` | `null` | no |
| <a name="input_aws_translate_region"></a> [aws\_translate\_region](#input\_aws\_translate\_region) | AWS region for Translate text translation service. Default to every var.aws\_bedrock\_regions region as a failover candidate, or the current region. | `string` | `null` | no |
| <a name="input_cloudwatch_logs_retention_in_days"></a> [cloudwatch\_logs\_retention\_in\_days](#input\_cloudwatch\_logs\_retention\_in\_days) | Cloudwatch logs retention in days. Applies to every log group this module and its child modules create, including the Container Insights performance log group. Security Hub: CloudWatch.16 (CloudWatch log groups should be retained for a specified time period) requires at least 365 days by default — default 365 = pass; lowering it fails this control. | `number` | `365` | no |
| <a name="input_cloudwatch_metrics"></a> [cloudwatch\_metrics](#input\_cloudwatch\_metrics) | If True, emit per-request AWS-billed usage as CloudWatch Embedded Metric Format (EMF) log lines. Default to false. | `bool` | `null` | no |
| <a name="input_cloudwatch_metrics_namespace"></a> [cloudwatch\_metrics\_namespace](#input\_cloudwatch\_metrics\_namespace) | CloudWatch namespace for the emitted usage metrics. Default to 'stdapi'. | `string` | `null` | no |
| <a name="input_cohere_routes_prefix"></a> [cohere\_routes\_prefix](#input\_cohere\_routes\_prefix) | Cohere API compatible routes prefix. Default to '/cohere'. | `string` | `null` | no |
| <a name="input_compliance_vpc_endpoints_enabled"></a> [compliance\_vpc\_endpoints\_enabled](#input\_compliance\_vpc\_endpoints\_enabled) | If true, add the interface VPC endpoints for ECR API, ECR Docker Registry, Systems Manager, SSM Incident Manager Contacts and SSM Incident Manager. Enable only if you have high compliance requirements — each interface endpoint adds cost. Security Hub: EC2.55/EC2.56/EC2.57/EC2.58/EC2.60 — default false = fail; set to true to pass. | `bool` | `false` | no |
| <a name="input_container_insight"></a> [container\_insight](#input\_container\_insight) | Container insight configuration. Valid values: 'enhanced', 'enabled', 'disabled'. Default to 'enabled'. Security Hub: ECS.12 (ECS clusters should use Container Insights) — default 'enabled' = pass; setting 'disabled' fails this control. | `string` | `"enabled"` | no |
| <a name="input_cors_allow_origins"></a> [cors\_allow\_origins](#input\_cors\_allow\_origins) | List of origins allowed to make cross-origin requests (CORS). Use ['*'] to allow all origins. Default to no CORS headers. | `list(string)` | `null` | no |
| <a name="input_cost_price_overrides"></a> [cost\_price\_overrides](#input\_cost\_price\_overrides) | Unit price overrides for models not covered by the AWS Price List API, as a map of model IDs to dimension-name/price maps. | `map(map(number))` | `null` | no |
| <a name="input_cost_tracking"></a> [cost\_tracking](#input\_cost\_tracking) | Enable per-request cost estimation from AWS Price List values (adds the pricing:GetProducts permission). Reported costs are an estimate from published prices, not your actual AWS bill; use cost\_price\_overrides for models the Price List API does not cover. Default to false. | `bool` | `null` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | ECS task CPU count. Valid values: 0.25, 0.5, 1, 2, 4, 8 & 16. Default of 0.25 vCPU is suitable for common use cases (text generation, embeddings). Increase for intensive workloads (multimodal requests, large LLM models). | `number` | `0.25` | no |
| <a name="input_cpu_architecture"></a> [cpu\_architecture](#input\_cpu\_architecture) | CPU architecture. Valid values: 'X86\_64' or 'ARM64'. | `string` | `"ARM64"` | no |
| <a name="input_default_model_params"></a> [default\_model\_params](#input\_default\_model\_params) | Default inference parameters applied to specific models automatically. JSON string format. | `string` | `null` | no |
| <a name="input_default_model_service_tiers"></a> [default\_model\_service\_tiers](#input\_default\_model\_service\_tiers) | Default service tier applied to specific models automatically when no explicit tier is provided (default, flex, priority, reserved). JSON string format, e.g. {"amazon.nova-pro-v1:0": "flex"}. | `string` | `null` | no |
| <a name="input_default_tts_language"></a> [default\_tts\_language](#input\_default\_tts\_language) | Default text-to-speech language to use if not specified in the request. Default to language autodetection. | `string` | `null` | no |
| <a name="input_default_tts_model"></a> [default\_tts\_model](#input\_default\_tts\_model) | Default text-to-speech model to use if not specified in the request. Default to 'amazon.polly-standard'. | `string` | `null` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | If true, enable deletion protection on eligible resources. | `bool` | `false` | no |
| <a name="input_dns_firewall_action"></a> [dns\_firewall\_action](#input\_dns\_firewall\_action) | Action taken by DNS Firewall when a query matches a domain from var.dns\_firewall\_managed\_domain\_list\_ids, and (if var.dns\_firewall\_advanced\_enabled) a DNS Firewall Advanced threat detection. Valid values: 'ALLOW', 'BLOCK', 'ALERT'. 'ALLOW' isn't valid for DNS Firewall Advanced rules, so it's treated as 'BLOCK' for those only. Ignored if var.dns\_firewall\_enabled is false. | `string` | `"BLOCK"` | no |
| <a name="input_dns_firewall_advanced_confidence_threshold"></a> [dns\_firewall\_advanced\_confidence\_threshold](#input\_dns\_firewall\_advanced\_confidence\_threshold) | Confidence threshold for DNS Firewall Advanced rules. Valid values: 'LOW', 'MEDIUM', 'HIGH'. Lower thresholds catch more threats at the cost of more false positives. Ignored if var.dns\_firewall\_advanced\_enabled is false. | `string` | `"HIGH"` | no |
| <a name="input_dns_firewall_advanced_enabled"></a> [dns\_firewall\_advanced\_enabled](#input\_dns\_firewall\_advanced\_enabled) | If true, add Route 53 Resolver DNS Firewall Advanced rules (additional cost) blocking DNS queries identified as domain generation algorithm (DGA) or DNS tunneling activity, on top of any managed-domain-list rules. Ignored if var.dns\_firewall\_enabled is false. | `bool` | `false` | no |
| <a name="input_dns_firewall_enabled"></a> [dns\_firewall\_enabled](#input\_dns\_firewall\_enabled) | If true, create a Route 53 Resolver DNS Firewall rule group and associate it with the dedicated VPC, blocking/alerting on DNS queries per var.dns\_firewall\_managed\_domain\_list\_ids and var.dns\_firewall\_advanced\_enabled. Helps mitigate malicious-URL injection via user-supplied URL/file references (images, documents, audio) by blocking outbound DNS resolution to known-malicious domains, in addition to the application's own SSRF protection. Only supported for the dedicated VPC this module creates; cannot be enabled when using external subnets (var.subnet\_ids). Not mapped to a Security Hub control; default false = feature not created. | `bool` | `false` | no |
| <a name="input_dns_firewall_managed_domain_list_ids"></a> [dns\_firewall\_managed\_domain\_list\_ids](#input\_dns\_firewall\_managed\_domain\_list\_ids) | Map of AWS Managed Domain List name to ID (e.g. { "AWSManagedDomainsAggregateThreatList" = "rslvr-fdl-..." }) to block/alert on via var.dns\_firewall\_action. Defaults (null) to the Aggregate Threat List ID built into the underlying VPC module for the current region, covering commercial regions enabled by default — no AWS CLI call or extra permissions required. For a region not covered by that default, look up the ID with 'aws route53resolver list-firewall-domain-lists' and pass it explicitly. Ignored if var.dns\_firewall\_enabled is false. Set to {} to skip managed-list rules while still using var.dns\_firewall\_advanced\_enabled. | `map(string)` | `null` | no |
| <a name="input_dns_firewall_priority"></a> [dns\_firewall\_priority](#input\_dns\_firewall\_priority) | Processing priority for the DNS Firewall rule group association within the VPC (lower is processed first). Must be unique among all rule group associations on the same VPC, including ones created outside this module. Ignored if var.dns\_firewall\_enabled is false. | `number` | `101` | no |
| <a name="input_drop_unsupported_system_prompt"></a> [drop\_unsupported\_system\_prompt](#input\_drop\_unsupported\_system\_prompt) | If true, system prompts are silently dropped when models don't support them. If false, an error is returned when a system prompt is passed to a model that doesn't support system prompts (e.g., mistral.mistral-7b models). Default: true for backward compatibility. | `bool` | `null` | no |
| <a name="input_ecs_task_role_policy_arns"></a> [ecs\_task\_role\_policy\_arns](#input\_ecs\_task\_role\_policy\_arns) | List of IAM policy ARNs to attach to the ECS task role. Use this to grant additional permissions to the ECS task, such as access to SSM parameters or Secrets Manager secrets specified in api\_key\_ssm\_parameter or api\_key\_secretsmanager\_secret. | `list(string)` | `[]` | no |
| <a name="input_enable_docs"></a> [enable\_docs](#input\_enable\_docs) | Enable interactive API documentation UI at /docs. Default to false. | `bool` | `null` | no |
| <a name="input_enable_gzip"></a> [enable\_gzip](#input\_enable\_gzip) | Enable GZip compression middleware for HTTP responses. Disabled by default. | `bool` | `null` | no |
| <a name="input_enable_mcp_sse"></a> [enable\_mcp\_sse](#input\_enable\_mcp\_sse) | Enable the MCP (Model Context Protocol) server using Server-Sent Events (SSE) transport. When enabled, exposes MCP endpoints at /sse. Maintained for backwards compatibility with older MCP clients; prefer enable\_mcp\_streamable\_http for new deployments. Default to false. | `bool` | `null` | no |
| <a name="input_enable_mcp_streamable_http"></a> [enable\_mcp\_streamable\_http](#input\_enable\_mcp\_streamable\_http) | Enable the MCP (Model Context Protocol) server using Streamable HTTP transport. When enabled, exposes an MCP-compatible endpoint at /mcp. This is the recommended MCP transport. Default to false. | `bool` | `null` | no |
| <a name="input_enable_openapi_json"></a> [enable\_openapi\_json](#input\_enable\_openapi\_json) | Enable OpenAPI JSON schema endpoint at /openapi.json. Default to false. | `bool` | `null` | no |
| <a name="input_enable_proxy_headers"></a> [enable\_proxy\_headers](#input\_enable\_proxy\_headers) | Enable ProxyHeadersMiddleware to trust X-Forwarded-* headers from reverse proxies. Automatically enabled when var.alb\_enabled is true and var.log\_client\_ip is true. | `bool` | `null` | no |
| <a name="input_enable_redoc"></a> [enable\_redoc](#input\_enable\_redoc) | Enable ReDoc API documentation UI at /redoc. Default to false. | `bool` | `null` | no |
| <a name="input_guardduty_vpc_endpoint_enabled"></a> [guardduty\_vpc\_endpoint\_enabled](#input\_guardduty\_vpc\_endpoint\_enabled) | If true, add the interface VPC endpoint required by GuardDuty Runtime Monitoring. Only relevant if you use GuardDuty Runtime Monitoring on resources in this VPC — leave false otherwise. Recommended whenever Runtime Monitoring is enabled, even with GuardDuty's automated agent configuration, since managing it here ensures correct subnet placement. Not mapped to a Security Hub control; default false = endpoint not created. | `bool` | `false` | no |
| <a name="input_image_generation_model"></a> [image\_generation\_model](#input\_image\_generation\_model) | Default model ID for image generation (e.g. 'amazon.nova-canvas-v1:0'). Required unless the client or the LLM specifies a model per call. | `string` | `null` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | If specified, directly use this KMS key instead of creating a dedicated one for the application. | `string` | `null` | no |
| <a name="input_log_client_ip"></a> [log\_client\_ip](#input\_log\_client\_ip) | If True, log the client IP address for each request and add it to OpenTelemetry spans. Default to false. | `bool` | `null` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Minimum logging level to output: info, warning, error, critical, or disabled. Default to info. | `string` | `null` | no |
| <a name="input_log_request_params"></a> [log\_request\_params](#input\_log\_request\_params) | If True, add requests and responses parameters to logs. Should not be enabled in production. Default to false. | `bool` | `null` | no |
| <a name="input_max_concurrent_input_downloads"></a> [max\_concurrent\_input\_downloads](#input\_max\_concurrent\_input\_downloads) | Maximum number of input files fetched or resolved concurrently within a single request, bounding outbound downloads against socket/memory exhaustion and SSRF amplification. Default to 8. | `number` | `null` | no |
| <a name="input_max_input_file_size"></a> [max\_input\_file\_size](#input\_max\_input\_file\_size) | Maximum size in bytes of an inline input file loaded into memory (base64, data URI, or a downloaded HTTP(S)/S3 source). Requests exceeding it are rejected with HTTP 413 before the content is fully decoded. Default to 0 (no limit). | `number` | `null` | no |
| <a name="input_mcp_exclude_tools"></a> [mcp\_exclude\_tools](#input\_mcp\_exclude\_tools) | Comma-separated list of MCP tool names to hide from MCP clients. All other tools remain exposed. When mcp\_include\_tools is also specified, these values are removed from it. Example: 'openai\_files\_delete,anthropic\_files\_delete' | `string` | `null` | no |
| <a name="input_mcp_include_tools"></a> [mcp\_include\_tools](#input\_mcp\_include\_tools) | Comma-separated list of MCP tool names to expose exclusively. Only the listed tools will be available to MCP clients; all others are hidden. When both mcp\_include\_tools and mcp\_exclude\_tools are specified, mcp\_exclude\_tools values are removed from mcp\_include\_tools. Example: 'openai\_chat\_completion,openai\_embedding,openai\_model\_list' | `string` | `null` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | ECS task memory (MiB). Valid values depends on the var.container\_cpu value (x1024), see the ECS documentation for more information. Default of 512 MiB is suitable for common use cases (text generation, embeddings). Increase for intensive workloads (multimodal requests, large LLM models). | `number` | `512` | no |
| <a name="input_model_aliases"></a> [model\_aliases](#input\_model\_aliases) | Map of model aliases to actual model IDs.<br/>Allows users to reference models using custom alias names.<br/>This is merged with default system aliases at startup.<br/>User-provided aliases take precedence over system defaults.<br/><br/>Example: {<br/>  "my-tts": "amazon.polly-neural",<br/>  "my-stt": "amazon.transcribe"<br/>} | `map(string)` | `null` | no |
| <a name="input_model_cache_seconds"></a> [model\_cache\_seconds](#input\_model\_cache\_seconds) | Cache lifetime in seconds for the Bedrock models list. | `number` | `null` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix to add to all created resources names. | `string` | `"stdapiai"` | no |
| <a name="input_nat_gateways_allowed"></a> [nat\_gateways\_allowed](#input\_nat\_gateways\_allowed) | If true, NAT gateways are used to give internet access to the application. If Disabled and internet access is required, application subnets will be public. Disable only if cost is privileged over security. | `bool` | `true` | no |
| <a name="input_openai_routes_prefix"></a> [openai\_routes\_prefix](#input\_openai\_routes\_prefix) | OpenAI API compatible routes prefix. | `string` | `null` | no |
| <a name="input_otel_enabled"></a> [otel\_enabled](#input\_otel\_enabled) | Enable OpenTelemetry distributed tracing. Default to false. | `bool` | `null` | no |
| <a name="input_otel_exporter_endpoint"></a> [otel\_exporter\_endpoint](#input\_otel\_exporter\_endpoint) | OpenTelemetry traces export endpoint URL. | `string` | `null` | no |
| <a name="input_otel_sample_rate"></a> [otel\_sample\_rate](#input\_otel\_sample\_rate) | OpenTelemetry trace sampling rate (0.0 to 1.0). | `number` | `null` | no |
| <a name="input_otel_service_name"></a> [otel\_service\_name](#input\_otel\_service\_name) | Service name identifier for OpenTelemetry traces. Default to 'stdapi.ai'. | `string` | `null` | no |
| <a name="input_proxy_trusted_hosts"></a> [proxy\_trusted\_hosts](#input\_proxy\_trusted\_hosts) | Trusted proxy hosts/IPs (CIDRs) whose X-Forwarded-* headers are honored when proxy headers are enabled. Restrict to your reverse proxy's IP range so direct clients cannot forge their source IP. When null and proxy headers are auto-enabled (var.alb\_enabled and var.log\_client\_ip both true), defaults to the ALB subnet CIDRs so only the ALB is trusted; otherwise the server default ('*') applies. | `list(string)` | `null` | no |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | If specified and 'subnet\_ids' is specified, use this security group instead of creating a new one giving access to internet and AWS services. | `string` | `null` | no |
| <a name="input_service_discovery_dns_name"></a> [service\_discovery\_dns\_name](#input\_service\_discovery\_dns\_name) | DNS name for service discovery. By default, uses the service name. Only if service\_discovery\_dns\_namespace\_id is specified. | `string` | `null` | no |
| <a name="input_service_discovery_dns_namespace_id"></a> [service\_discovery\_dns\_namespace\_id](#input\_service\_discovery\_dns\_namespace\_id) | If specified, enable Service discovery on the ECS service and attach it to this Cloud Map namespace. | `string` | `null` | no |
| <a name="input_sns_topic_arn"></a> [sns\_topic\_arn](#input\_sns\_topic\_arn) | SNS topic ARN for CloudWatch alarms. If specified, CloudWatch alarms will be created for high memory usage and unhealthy containers. | `string` | `null` | no |
| <a name="input_ssrf_protection_block_private_networks"></a> [ssrf\_protection\_block\_private\_networks](#input\_ssrf\_protection\_block\_private\_networks) | Enable SSRF protection by blocking requests to private/local networks. When enabled, the server will reject requests to RFC 1918 private addresses (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16), loopback, link-local, reserved, and multicast addresses. Default to true. | `bool` | `null` | no |
| <a name="input_strict_input_validation"></a> [strict\_input\_validation](#input\_strict\_input\_validation) | If True, raise error on extra fields in input request. Default to false. | `bool` | `null` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | If specified, directly use theses subnets instead of creating a dedicated VPC. | `list(string)` | `[]` | no |
| <a name="input_timezone"></a> [timezone](#input\_timezone) | Timezone for request date & time (IANA timezone identifier). Default to UTC. | `string` | `null` | no |
| <a name="input_tokens_estimation"></a> [tokens\_estimation](#input\_tokens\_estimation) | Deprecated and ignored since stdapi.ai v1.14.0: token estimation has been removed; only real AWS-billed usage is reported. | `bool` | `null` | no |
| <a name="input_tokens_estimation_default_encoding"></a> [tokens\_estimation\_default\_encoding](#input\_tokens\_estimation\_default\_encoding) | Deprecated and ignored since stdapi.ai v1.14.0: token estimation has been removed. | `string` | `null` | no |
| <a name="input_trusted_hosts"></a> [trusted\_hosts](#input\_trusted\_hosts) | List of trusted host header values for Host header validation. Supports wildcard subdomains. Disabled by default. | `list(string)` | `null` | no |
| <a name="input_version_to_deploy"></a> [version\_to\_deploy](#input\_version\_to\_deploy) | Container image version tag from AWS Marketplace. Leave unset to automatically use the latest stable version. Only override for testing or rollback purposes. A '-arm64' or '-amd64' suffix is appended automatically based on var.cpu\_architecture, so the value must not include an architecture suffix. | `string` | `"1.15.0"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the dedicated VPC. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_endpoints_allowed"></a> [vpc\_endpoints\_allowed](#input\_vpc\_endpoints\_allowed) | If true, VPC endpoints interfaces are privileged to give AWS services access to the application if no internet access is required. VPC endpoint Gateway are always provisioned. Disable only if cost is privileged over security. | `bool` | `true` | no |
| <a name="input_vpc_flow_log_enabled"></a> [vpc\_flow\_log\_enabled](#input\_vpc\_flow\_log\_enabled) | If true, enable VPC flow log. Disable only if cost is privileged over security. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
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
| <a name="output_regional_buckets"></a> [regional\_buckets](#output\_regional\_buckets) | Map of region → bucket name (user-provided + auto-created). |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID for the ECS server service. |
| <a name="output_service_discovery_service_name"></a> [service\_discovery\_service\_name](#output\_service\_discovery\_service\_name) | Service discovery service name for the server (only if service discovery is enabled). |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | ECS service name. |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Subnets IDs where the ECS service is deployed. |
<!-- END_TF_DOCS -->
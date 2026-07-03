# stdapi.ai - Terraform Module for AWS

[![Terraform Module](https://img.shields.io/badge/Terraform-Enterprise%20Edition%20module-844FBA?logo=terraform&logoColor=ffffff)](https://registry.terraform.io/modules/stdapi-ai/stdapi-ai/aws/latest)
[![OpenTofu Module](https://img.shields.io/badge/OpenTofu-Enterprise%20Edition%20module-FFDA18?logo=opentofu&logoColor=ffffff)](https://search.opentofu.org/module/stdapi-ai/stdapi-ai/aws/latest)

**Deploy an OpenAI & Anthropic compatible AI gateway on AWS in minutes.** Production-ready ECS Fargate infrastructure with HTTPS, WAF, auto-scaling, and monitoring — all from a single Terraform module.

🌐 [Documentation](https://stdapi.ai) · 🚀 [Start 14-Day Free Trial](https://stdapi.ai/operations_getting_started/) · 💻 [GitHub Repository](https://github.com/stdapi-ai/stdapi.ai)

## Quick Start

### Prerequisites

1. **[Subscribe to stdapi.ai](https://aws.amazon.com/marketplace/pp/prodview-su2dajk5zawpo)** on AWS Marketplace (14-day free trial included)
2. Install [Terraform](https://www.terraform.io/downloads) or [OpenTofu](https://opentofu.org/docs/intro/install/) >= 1.5
3. Configure [AWS credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)

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

  # Public HTTPS endpoint on a custom domain (ACM cert auto-issued via Route53)
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

For ready-to-deploy variants (single-region, EU/US multi-region, Open WebUI), see the [**samples repository**](https://github.com/stdapi-ai/samples). For deeper patterns (BYO VPC / ALB / Route53 / S3, manual ECS, cost-optimized), see the [**advanced deployment guide**](https://stdapi.ai/operations_deploy_advanced/).

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
                │   WAF    (optional)  │   alb_waf_enabled
                └──────────┬──────────┘
                           │  inbound only when the ALB is enabled
                ┌──────────▼──────────┐
                │   ALB    (optional)  │   alb_enabled / alb_public
                │   HTTPS / HTTP       │   (public subnets only if alb_public)
                └──────────┬──────────┘
                           │
   ┌───────────────────────┼───────────────────────┐
   │ VPC (dedicated, or bring-your-own subnet_ids)  │
   │                       │                        │
   │            ┌──────────▼──────────┐  S3 gateway        ┌──────────────┐
   │            │     ECS Fargate     │  endpoint          │  S3 Bucket   │
   │            │   ┌─────────────┐   │  (always, free) ──▶│ (+ regional  │
   │            │   │  stdapi.ai  │   │             │      │  buckets,    │
   │            │   │  Container  │   │             │      │  KMS-encr.)  │
   │            │   └─────────────┘   │             │      └──────────────┘
   │            │  app subnet (private)             │
   │            └──────────┬──────────┘             │
   │     egress to Bedrock, Polly, Transcribe, …    │
   │     uses exactly ONE of (mutually exclusive):  │
   │       • NAT gateways            (default)      │
   │       • Interface VPC endpoints (no-internet)  │
   └───────────────────────┬───────────────────────┘
                           │
                ┌──────────▼──────────┐
                │      CloudWatch      │
                └─────────────────────┘
```

### What gets provisioned, and when

| Component                                                                                                                                                                         | Created when                                                                                                                                                                                                                                                                                                                                                   |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Dedicated VPC, private app subnets, ECS Fargate service, KMS-encrypted S3 bucket(s), **S3 gateway endpoint**, CloudWatch logs                                                     | Always — unless you pass your own `subnet_ids`, which skips VPC/subnet/endpoint creation entirely                                                                                                                                                                                                                                                              |
| **NAT gateways** (private internet egress)                                                                                                                                        | **Default.** Created whenever the app needs internet: AWS Marketplace auto-subscribe is on (`aws_bedrock_marketplace_auto_subscribe`, default `true`) **or** any AWS service runs outside the deployment region (e.g. multi-region `aws_bedrock_regions`). Set `nat_gateways_allowed = false` to instead make the app subnets public (cheaper, less isolated). |
| **Interface VPC endpoints** — Bedrock, Polly, Transcribe, Comprehend, Translate, Logs, SSM, ECR, Marketplace metering (Secrets Manager only with `api_key_secretsmanager_secret`) | Only when the app needs **no** internet egress: `aws_bedrock_marketplace_auto_subscribe = false` **and** every AWS service is in the deployment region **and** `vpc_endpoints_allowed = true` (default). Replaces the NAT path — the two are never created together.                                                                                           |
| Public subnets                                                                                                                                                                    | Only with a public ALB (`alb_enabled = true` **and** `alb_public = true`)                                                                                                                                                                                                                                                                                      |
| ALB + HTTPS listener / ACM certificate                                                                                                                                            | `alb_enabled = true` (HTTPS when `alb_domain_name` / `alb_certificate_arn` is set; auto ACM + Route53 via `alb_domain_name`). Without an ALB the service is only reachable from inside the VPC.                                                                                                                                                                |
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

For integration patterns against existing infrastructure (BYO VPC, ALB, Route53 zone, or S3 bucket) and non-Terraform deployments (manual ECS, EKS), see the [**advanced deployment guide**](https://stdapi.ai/operations_deploy_advanced/).

## Documentation

| Resource | Description |
|---|---|
| **[Getting Started](https://stdapi.ai/operations_getting_started/)** | Deployment examples and first API call |
| **[Advanced Deployment](https://stdapi.ai/operations_deploy_advanced/)** | VPC integration, multi-region, cost optimization |
| **[Configuration](https://stdapi.ai/operations_configuration/)** | All environment variables and module parameters |
| **[API Reference](https://stdapi.ai/api_overview/)** | OpenAI & Anthropic compatible API documentation |
| **[Use Cases](https://stdapi.ai/use_cases/)** | Open WebUI, n8n, coding assistants, and more |
| **[Features](https://stdapi.ai/features/)** | Full product capabilities |

## Technical Requirements

- **AWS Marketplace Subscription** — [Subscribe here](https://aws.amazon.com/marketplace/pp/prodview-su2dajk5zawpo) (14-day free trial included)
- **AWS Regions** — All regions with ECS Fargate support
- **IAM Permissions** — Permissions to create VPC, ECS, ALB, S3, KMS, IAM, CloudWatch resources

See [Requirements](#requirements) below for exact Terraform/OpenTofu and provider version constraints.

## Security Hub Controls

This module composes `terraform-aws-vpc`, `terraform-aws-ecs-fargate` and `terraform-aws-kms-key`. The tables below give each child module's controls **as they actually resolve given the parameters this module passes** — not the child modules' standalone defaults, which sometimes differ (e.g. this module always passes a non-null `tags` value and a 365-day `cloudwatch_logs_retention_in_days`, which changes several outcomes). See each repo's own README for the full control reference and remediation detail; only the controls whose resolution is worth calling out are listed here.

### VPC module (`terraform-aws-vpc`)

Key inputs this module passes: `tags = local.apn_tags` (never null), `vpc_flow_log_retention_days = var.cloudwatch_logs_retention_in_days` (default `365`, matching the child module's own default), `internet_access_allowed = local.internet_access_required` (computed — **defaults to `true`** here, since `aws_bedrock_marketplace_auto_subscribe` defaults to `null`, which resolves to "auto-subscribe enabled" and requires internet access for the AWS Marketplace API), `nat_gateways_allowed = var.nat_gateways_allowed` (default `true`), `vpc_endpoints_services` already includes `s3`, `ssm`, `logs`, `ecr.api`, `ecr.dkr` by default (see `network.tf`).

Severity: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low

| Control | Severity | Title | Status | Notes |
|---|---|---|---|---|
| EC2.2 | 🟠 High | VPC default security groups should restrict all traffic | ✅ Pass | Unconditional in the VPC module. |
| EC2.6 | 🟡 Medium | VPC flow logging should be enabled in all VPCs | ✅ Pass | `vpc_flow_log_enabled` defaults `true`, not overridden. |
| EC2.15 | 🟡 Medium | EC2 subnets should not automatically assign public IP addresses | ✅ Pass | Even though `internet_access_allowed` is `true` by default, `nat_gateways_allowed` also defaults `true`, so NAT (not public IPs) handles egress. Setting `nat_gateways_allowed = false` would fail this control. |
| EC2.21 | 🟡 Medium | Network ACLs should not allow ingress from 0.0.0.0/0 to port 22/3389 | ✅ Pass | This module sets `public_to_app_ports` to port 8000 and `public_ingress_ports` to 80/443 — never 22/3389. |
| EC2.53 / EC2.54 / EC2.13 / EC2.14 | 🟠 High | Security groups should not allow ingress from 0.0.0.0/0 to remote administration ports | ✅ Pass | Unconditional in the VPC module. |
| EC2.12 | 🔵 Low | Unused EIPs should be removed | ✅ Pass | Unconditional. |
| EC2.37 / EC2.39 / EC2.40 / EC2.41 / EC2.42 / EC2.43 / EC2.44 / EC2.46 / EC2.174 | 🔵 Low | Various VPC resources should be tagged | ✅ Pass | Unconditional (a `Name` tag is always merged in regardless of `tags`). |
| EC2.48 | 🔵 Low | VPC flow logs should be tagged | ✅ Pass | The flow log applies `tags` directly with no fallback — this module passes `local.apn_tags` (non-null), so it's actually tagged. Would fail if `tags` were left at the VPC module's own default (`null`). |
| IAM.24 | 🔵 Low | IAM roles should be tagged | ✅ Pass | Same reasoning as EC2.48, for the flow log's IAM role. |
| CloudWatch.16 | 🟡 Medium | CloudWatch log groups should be retained for a specified time period | ✅ Pass | `vpc_flow_log_retention_days` is set to `var.cloudwatch_logs_retention_in_days` (default `365`), matching the VPC module's own default (also `365`) — kept as an explicit pass-through so this module's single retention variable stays authoritative across all child modules. |
| EC2.55 / EC2.56 / EC2.57 / EC2.58 / EC2.60 | 🟡 Medium | VPCs should be configured with an interface endpoint for ECR API / Docker Registry / SSM / SSM Incident Manager Contacts / SSM Incident Manager | ⚠️ Conditional (default: ❌ Fail) | `vpc_endpoints_services` already requests `ecr.api`/`ecr.dkr`/`ssm` by default — but that request only takes effect when there's no direct internet route, and by default there is one (see above). The request is a silent no-op under default settings. Set `compliance_vpc_endpoints_enabled = true` to actually get these 5 endpoints created, since that path is enforced regardless of internet posture. |
| — (not a Security Hub control) | — | GuardDuty Runtime Monitoring endpoint | Off by default | Set `guardduty_vpc_endpoint_enabled = true` if using GuardDuty Runtime Monitoring; also enforced regardless of internet posture. |
| — (not a Security Hub control) | — | Route 53 Resolver DNS Firewall | Off by default | Set `dns_firewall_enabled = true` to block/alert on DNS queries to known-malicious domains (AWS Managed Domain Lists, plus DGA/DNS-tunneling detection via `dns_firewall_advanced_enabled`). Complements application-level SSRF protection by adding a network-layer control against malicious-URL injection through user-supplied URL/file reference fields. **Dedicated VPC only** — has no effect (and cannot be enabled) when `subnet_ids` is set, since DNS Firewall associates with the VPC resource this module creates. |

### KMS module (`terraform-aws-kms-key`)

Key inputs: this module builds `policy_documents_json` itself (its own log-encryption statement, plus whatever `module.vpc`/`module.server` need added) and always passes non-null `tags`. The per-Bedrock-region keys (`module.regional_kms`) pass only `name_prefix`, `region` and `tags` — no `policy_documents_json` override.

Severity: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low

| Control | Severity | Title | Status | Notes |
|---|---|---|---|---|
| KMS.1 / KMS.2 | 🟡 Medium | IAM policies/inline policies should not allow decryption on all KMS keys | ⬜ N/A | No IAM policies are created by the KMS module. |
| KMS.3 | 🔴 Critical | KMS keys should not be deleted unintentionally | ✅ Pass | No `deletion_window_in_days` override — AWS's 30-day maximum applies. |
| KMS.4 | 🟡 Medium | KMS key rotation should be enabled | ✅ Pass | Hardcoded in the KMS module for every key it creates, including the regional ones. |
| KMS.5 | 🔴 Critical | KMS keys should not be publicly accessible | ✅ Pass | Every statement merged into `policy_documents_json` (this module's log policy, plus `module.vpc.kms_policy_documents_json` and `module.server.kms_policy_documents_json`) scopes a specific AWS service principal with an `ArnLike`/`StringEquals` condition — none is a wildcard principal. The regional keys use the KMS module's safe root-only default. |

### ECS module (`terraform-aws-ecs-fargate`)

Key inputs: `tags = local.apn_tags` (never null), `assign_public_ip = local.internet_access_required && !var.nat_gateways_allowed`, `container_insight = var.container_insight` (default `"enabled"`), `cloudwatch_logs_retention_in_days = var.cloudwatch_logs_retention_in_days` (default `365`), no `security_group_rules_ingress`/`security_group_connect_ingress` passed, and the `main` container definition sets `read_only_root_filesystem = true` but never sets `user`, and its only mount point (`/tmp`) is ephemeral, not EFS.

Severity: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low

| Control | Severity | Title | Status | Notes |
|---|---|---|---|---|
| ECS.2 | 🟠 High | Services should not have public IP addresses assigned automatically | ✅ Pass | `assign_public_ip` is always `false` in the default composition, since `nat_gateways_allowed` defaults `true` — regardless of `internet_access_required`. Would fail only if `nat_gateways_allowed` is set to `false`. |
| ECS.3 / ECS.4 / ECS.9 | 🟠 High | Various ECS controls (host PID namespace, non-privileged, logging config) | ✅ Pass | Same as the ECS module's own unconditional defaults — this module doesn't change any of these. |
| ECS.16 | 🟠 High | ECS task sets should not automatically assign public IP addresses | ⬜ N/A | Module manages `aws_ecs_service` directly, never `aws_ecs_task_set`. |
| ECS.10 / ECS.17 / ECS.18 | 🟡 Medium | Various ECS controls (Fargate platform version, host network mode, EFS in-transit encryption) | ✅ Pass | Same as the ECS module's own unconditional defaults — this module doesn't change any of these. |
| ECS.19 / ECS.21 | 🟡 Medium | Capacity provider termination protection / non-administrator users for Windows containers | ⬜ N/A | Only Fargate capacity providers and Linux containers are used. |
| ECS.14 | 🔵 Low | ECS clusters should be tagged | ✅ Pass | The cluster always receives a `Name` tag regardless of `tags`. |
| ECS.5 | 🟠 High | Task definitions should use read-only root filesystems | ✅ Pass | `read_only_root_filesystem = true` is explicitly set on the `main` container in `server.tf`. |
| ECS.8 | 🟠 High | Secrets should not be passed as container environment variables | ✅ Pass | The API key is passed via `secrets`, never `environment`. |
| ECS.12 | 🟡 Medium | ECS clusters should use Container Insights | ✅ Pass | `container_insight` defaults to `"enabled"`. |
| ECS.13 / ECS.15 | 🔵 Low | Service / task definition should be tagged | ✅ Pass | `tags = local.apn_tags` (non-null) is forwarded — these two resources apply that value directly with no fallback, so they're actually tagged, unlike the ECS module's own default (`null`). |
| ECS.20 | 🟡 Medium | Task definitions should configure non-root users for Linux containers | ✅ Pass | `user = "65532:65532"` is set explicitly on the `main` container, matching the Chainguard `python:latest` base image's actual default non-root user (`nonroot`, uid/gid 65532) — a declaration of existing behavior, not a change to it. |
| EC2.13 / EC2.14 / EC2.18 / EC2.53 / EC2.54 | 🟠 High | Security groups should not allow unrestricted/admin-port ingress | ✅ Pass | No `security_group_rules_ingress`/`security_group_connect_ingress` are passed. The only extra ingress rule (`aws_vpc_security_group_ingress_rule.ecs_from_alb` in `alb.tf`) references the ALB's security group, never a CIDR. |
| EC2.19 | 🔴 Critical | Security groups should not allow unrestricted access to ports with high risk | ✅ Pass | Same reasoning as EC2.13/14/18/53/54 above. |
| EC2.43 | 🔵 Low | Security groups should be tagged | ✅ Pass | Unconditional. |
| EFS.1 – EFS.4 / EFS.6 – EFS.8 | 🟡 Medium | Various EFS controls | ⬜ N/A | This module's only mount point (`/tmp`) uses ephemeral storage (`efs` isn't set to `true`), so no EFS resources exist at all. |
| EFS.5 | 🔵 Low | EFS access points should be tagged | ⬜ N/A | Same reason — no EFS resources exist. |
| CloudWatch.15 | 🟠 High | CloudWatch alarms should have specified actions configured | ⚠️ Conditional (default: N/A — no alarms) | `alarms_enabled` defaults `false`, so no alarms exist to evaluate. Set `alarms_enabled = true` and `sns_topic_arn` to pass. |
| CloudWatch.16 | 🟡 Medium | CloudWatch log groups should be retained for a specified time period | ✅ Pass | `cloudwatch_logs_retention_in_days` defaults `365`, applied to every log group the ECS module creates, including Container Insights. |
| CloudWatch.17 | 🟠 High | CloudWatch alarm actions should be activated | ✅ Pass | Unconditional. |
| IAM.1 | 🟠 High | IAM policies should not allow full "*" administrative privileges | ✅ Pass | The ECS module's own execution/task role policies use no wildcard actions (also true of this module's separate `aws_iam_policy.server`, listed below). |

### This module's own resources (ALB, WAFv2, ACM/Route 53, S3, aggregated IAM policy)

Severity: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low

| Control | Severity | Title | Status | Options to pass |
|---|---|---|---|---|
| ELB.1 | 🟡 Medium | Application Load Balancers should be configured to redirect all HTTP requests to HTTPS | ⚠️ Conditional (default: ❌ Fail) | The HTTP listener only redirects to HTTPS when a certificate exists. Set `alb_certificate_arn` or `alb_domain_name` (with a resolvable Route 53 zone) to get a certificate and enable the redirect. Only relevant when `alb_enabled = true` (default `false`). |
| ELB.4 | 🟡 Medium | ALB should be configured to drop invalid HTTP headers | ✅ Pass | `drop_invalid_header_fields = true` is hardcoded; not configurable (no legitimate reason to disable it). |
| ELB.5 | 🟡 Medium | Application Load Balancers should have logging enabled | ⚠️ Conditional (default: ✅ Pass) | Set `alb_access_logging_enabled = true` (default) to pass — a dedicated SSE-S3-encrypted `aws_s3_bucket.alb_logs` is created and wired to the load balancer's `access_logs` block. Setting it to `false` fails this control. The previous `aws_cloudwatch_log_group.alb` (dead code — ALB access logs can only go to S3, not CloudWatch) has been removed. |
| ELB.6 | 🟡 Medium | Application, Network, and Gateway Load Balancers should have deletion protection enabled | ⚠️ Conditional (default: ❌ Fail) | Set `deletion_protection = true` (default `false`) to pass. |
| ELB.12 | 🟡 Medium | Application Load Balancers should be configured with defensive or strictest desync mitigation mode | ✅ Pass | Not set explicitly, but AWS's own default (`defensive`) satisfies the control. |
| ELB.13 | 🟡 Medium | Application, Network, and Gateway Load Balancers should span multiple Availability Zones | ⚠️ Conditional (default: ✅ Pass) | Subnets come from the VPC module, which uses all available AZs by default (`availability_zones_count = null`) — always ≥2 in practice. Passes unless `availability_zones_count` is explicitly set to `1`. |
| ELB.16 | 🟡 Medium | Application Load Balancers should be associated with a WAF web ACL | ⚠️ Conditional (default: ❌ Fail) | Set `alb_waf_enabled = true` (default `false`) to pass, in addition to `alb_enabled = true`. |
| ELB.17 | 🟡 Medium | Application/Network Load Balancer listeners should use recommended security policies | ⚠️ Conditional (default: ✅ Pass once HTTPS exists, N/A otherwise) | `alb_ssl_policy` defaults to `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09`, one of AWS's recommended policies. Only applies once the HTTPS listener exists (see ELB.1). |
| ELB.18 | 🟡 Medium | ALB/NLB listeners should be configured with a secure listener protocol | ❌ Fail | The HTTP listener (port 80) is always created with `protocol = "HTTP"`; there's no exemption for a redirect-only listener. Unavoidable while any HTTP listener exists — inherent to offering both HTTP and HTTPS. |
| ELB.21 | 🟡 Medium | ELB target groups should have health check configured with encrypted protocol | ❌ Fail | The target group's health check uses the default `HTTP` protocol; no variable exposes HTTPS health checks. Requires a code change to pass. |
| ELB.22 | 🟡 Medium | ELB target groups should use encrypted transport protocol | ❌ Fail | The target group forwards to the ECS task over plain `HTTP` on the container port (TLS is terminated at the ALB, not re-established to the backend). Requires a code change (HTTPS target group + TLS-terminating container) to pass. |
| ELB.2 / ELB.3 / ELB.8 / ELB.9 / ELB.10 / ELB.14 | 🟡 Medium | Various Classic Load Balancer controls | ⬜ N/A | Module only creates an Application Load Balancer, never a Classic Load Balancer. |
| ELB.7 | 🔵 Low | CLB connection draining should be enabled | ⬜ N/A | Module only creates an Application Load Balancer, never a Classic Load Balancer. |
| WAFV2.1 (AWS WAF `WAF.10`) | 🟡 Medium | AWS WAF web ACLs should have at least one rule or rule group | ⚠️ Conditional (default: N/A — no WAF created; ✅ Pass once enabled) | Gated by `alb_enabled && alb_waf_enabled` (both default `false`). Once enabled, three AWS managed rule groups are always attached — never empty. |
| WAFV2.2 (AWS WAF `WAF.11`) | 🔵 Low | AWS WAF web ACL logging should be enabled | ⚠️ Conditional (default: N/A — no WAF created; ✅ Pass once enabled) | `alb_waf_logging_enabled` defaults `true`, so logging is on whenever WAF is created. Setting it to `false` fails this control. |
| ACM.1 | 🟡 Medium | Imported and ACM-issued certificates should be renewed after a specified time period | ✅ Pass | The certificate uses DNS validation (`validation_method = "DNS"`), which ACM renews automatically. |
| ACM.2 | 🟠 High | RSA certificates managed by ACM should use a key length of at least 2,048 bits | ✅ Pass | `key_algorithm` isn't set, so ACM uses its default `RSA_2048`. |
| ACM.3 | 🔵 Low | ACM certificates should be tagged | ✅ Pass | Tagged via `local.apn_tags` plus a `Name` tag. |
| Route53.1 | 🔵 Low | Route 53 health checks should be tagged | ⬜ N/A | Module creates no `aws_route53_health_check` resource. |
| Route53.2 | 🟡 Medium | Route 53 public hosted zones should log DNS queries | ⬜ N/A | The module only looks up or references an existing hosted zone — it never creates one, so this is outside its control. |
| S3.2 / S3.3 | 🔴 Critical | S3 buckets should block public read/write access | ✅ Pass | `aws_s3_bucket_public_access_block` sets all four flags to `true` for every bucket (main and regional). |
| S3.8 | 🟠 High | S3 buckets should block public access (account/bucket combined check) | ✅ Pass | Same `aws_s3_bucket_public_access_block` configuration as S3.2/S3.3. |
| S3.5 | 🟡 Medium | S3 buckets should require requests to use SSL | ✅ Pass | Bucket policy denies all `s3:*` actions when `aws:SecureTransport` is false. |
| S3.6 | 🟠 High | S3 bucket policies should restrict access to other AWS accounts | ✅ Pass | The only statement is the TLS-enforcement `Deny`; no cross-account `Allow`. |
| S3.9 | 🟡 Medium | S3 buckets should have server access logging enabled | ✅ Pass | The main bucket logs to a shared SSE-S3-encrypted `aws_s3_bucket.logs` (also used for ALB access logs, `alb.tf`). Each regional bucket logs to its own per-Region `aws_s3_bucket.regional_logs` (`storage_regional.tf`) — S3 access log destinations must be in the same Region as their source bucket (confirmed via AWS's own docs), so a single cross-Region log bucket isn't possible; this mirrors the existing per-Region `regional_kms` pattern. |
| S3.10 | 🟡 Medium | S3 buckets with versioning enabled should have lifecycle configurations | ✅ Pass | Every bucket gets an unconditional lifecycle configuration (tmp cleanup, files expiration, intelligent-tiering). |
| S3.13 | 🔵 Low | S3 buckets should have lifecycle configurations | ✅ Pass | Same lifecycle configuration as S3.10. |
| S3.11 | 🟡 Medium | S3 buckets should have event notifications enabled | ✅ Pass | `aws_s3_bucket_notification` with `eventbridge = true` is set unconditionally on the main and every regional bucket — zero-config, no targets/rules required, no cost unless rules are later added. |
| S3.12 | 🟡 Medium | ACLs should not be used to manage access to S3 buckets | ✅ Pass | No ACL is configured; new buckets default to `BucketOwnerEnforced` (ACLs disabled). |
| S3.14 | 🔵 Low | S3 buckets should have versioning enabled | ✅ Pass | `status = "Enabled"` unconditionally on every bucket. |
| S3.15 | 🟡 Medium | S3 buckets should have Object Lock enabled | ⬜ N/A | Object Lock (WORM immutability) doesn't fit this bucket's purpose — it's mainly temporary storage with active expiration lifecycle rules (1-day tmp cleanup, 30-day Files API expiration), the opposite of what Object Lock is for. |
| S3.17 | 🟡 Medium | S3 buckets should be encrypted at rest with AWS KMS keys | ✅ Pass | SSE-KMS with a dedicated customer-managed key, `bucket_key_enabled = true`, for every bucket. |
| S3.20 | 🔵 Low | S3 buckets should have MFA delete enabled | ⬜ N/A (exempt) | AWS's own control text exempts buckets that have a lifecycle configuration — both `main` and `regional` buckets always have one, so this control never evaluates them. |
| S3.22 / S3.23 | 🟡 Medium | S3 buckets should log object-level read/write events | ⬜ N/A | Account-level control requiring an org-wide multi-Region CloudTrail trail; outside this module's scope. |
| IAM.1 | 🟠 High | IAM policies should not allow full administrative privileges | ✅ Pass | `aws_iam_policy.server`'s statements all use specific actions (`bedrock:*`, `s3:*` object-level actions, etc.); none use `Action: "*"`. |
| IAM.21 | 🔵 Low | IAM customer managed policies should not allow wildcard actions for services | ✅ Pass | Same statements as IAM.1 — no wildcard (`service:*`) actions. |

**Overall summary — with every variable at its default:**
- **VPC/ECS/KMS child modules:** thanks to this module always passing non-null `tags`, several controls that fail by default in the *standalone* child modules (EC2.48, IAM.24, ECS.13/ECS.15) actually **pass** here. CloudWatch.16 now passes by default in both child modules directly (their own `vpc_flow_log_retention_days`/`cloudwatch_logs_retention_in_days` defaults were uniformized to `365`), and ECS.20 also now passes (explicit `user`). One gap remains: **EC2.55/EC2.56/EC2.57/EC2.58/EC2.60** — the interface endpoints this module already requests in `vpc_endpoints_services` are silently ineffective by default, because internet access is required for AWS Marketplace auto-subscribe. Set `compliance_vpc_endpoints_enabled = true` to actually get them.
- **This module's own resources:** with `alb_enabled = false` (default), none of the ALB/WAF/ACM controls apply — no load balancer exists. Once `alb_enabled = true`, ELB.4 and ELB.5 now pass out of the box (dropped invalid headers, S3 access logging with a dedicated bucket). The ALB still fails **ELB.18, ELB.21, ELB.22 unconditionally** — these would require re-architecting to terminate TLS on the backend as well, not just adding a variable — and fails **ELB.1, ELB.6, ELB.16 by default** until their respective variables are set. The S3 buckets (created by default) now pass **S3.9 and S3.11** unconditionally too; S3.15 (Object Lock) doesn't apply given this bucket's temporary-storage purpose.

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
| <a name="module_vpc"></a> [vpc](#module\_vpc) | JGoutin/vpc/aws | ~> 1.1 |

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
| <a name="input_alb_domain_name"></a> [alb\_domain\_name](#input\_alb\_domain\_name) | Primary domain name for the application (e.g., api.example.com). Creates Route53 A record and ACM certificate. If route53\_zone\_id is not specified, automatically looks up the most specific parent domain zone. | `string` | `null` | no |
| <a name="input_alb_enabled"></a> [alb\_enabled](#input\_alb\_enabled) | If true, create an Application Load Balancer for the ECS service. Cannot be used with external subnets (subnet\_ids). | `bool` | `false` | no |
| <a name="input_alb_idle_timeout"></a> [alb\_idle\_timeout](#input\_alb\_idle\_timeout) | The time in seconds that the connection is allowed to be idle. Range: 1-4000 seconds. Default to 3600 (1 hour) to support slow LLM responses and long-running operations like AWS Transcribe. | `number` | `3600` | no |
| <a name="input_alb_ingress_ipv4_cidrs"></a> [alb\_ingress\_ipv4\_cidrs](#input\_alb\_ingress\_ipv4\_cidrs) | List of IPv4 CIDR blocks allowed to access the ALB. Default to ['0.0.0.0/0'] for public access. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_alb_ingress_ipv6_cidrs"></a> [alb\_ingress\_ipv6\_cidrs](#input\_alb\_ingress\_ipv6\_cidrs) | List of IPv6 CIDR blocks allowed to access the ALB. Default to ['::/0'] for public access. | `list(string)` | <pre>[<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_alb_public"></a> [alb\_public](#input\_alb\_public) | If true, create a public (internet-facing) ALB with dedicated public subnets. If false, create a private (internal) ALB using app subnets. | `bool` | `false` | no |
| <a name="input_alb_route53_zone_id"></a> [alb\_route53\_zone\_id](#input\_alb\_route53\_zone\_id) | Route53 hosted zone ID for DNS records. If not specified, automatically infers the zone from the parent domain of domain\_name (e.g., 'api.example.com' → 'example.com', 'api.sandbox.example.com' → 'sandbox.example.com'). | `string` | `null` | no |
| <a name="input_alb_route53_zone_name"></a> [alb\_route53\_zone\_name](#input\_alb\_route53\_zone\_name) | Route53 hosted zone name for DNS records (e.g., 'example.com'). Alternative to route53\_zone\_id - module will look up the zone ID automatically. If specified with domain\_name, creates DNS records and ACM certificate. | `string` | `null` | no |
| <a name="input_alb_route53_zone_private"></a> [alb\_route53\_zone\_private](#input\_alb\_route53\_zone\_private) | If true, the Route53 zone is private. If false, it's public. Used when looking up the zone by name. | `bool` | `false` | no |
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
| <a name="input_aws_bedrock_allow_prompt_router_arn"></a> [aws\_bedrock\_allow\_prompt\_router\_arn](#input\_aws\_bedrock\_allow\_prompt\_router\_arn) | If True, allow users to pass prompt router ARNs directly as model IDs. Prompt routers enable dynamic model selection based on prompt characteristics. When disabled, only standard model IDs and configured profiles are accepted. | `bool` | `null` | no |
| <a name="input_aws_bedrock_cross_region_inference"></a> [aws\_bedrock\_cross\_region\_inference](#input\_aws\_bedrock\_cross\_region\_inference) | If true, allow cross region inference to be used. Default to true. | `bool` | `null` | no |
| <a name="input_aws_bedrock_cross_region_inference_global"></a> [aws\_bedrock\_cross\_region\_inference\_global](#input\_aws\_bedrock\_cross\_region\_inference\_global) | If True, allow 'global' cross region inference that can route requests to any region, worldwide. Default to true. | `bool` | `null` | no |
| <a name="input_aws_bedrock_deprecated_model_fallback"></a> [aws\_bedrock\_deprecated\_model\_fallback](#input\_aws\_bedrock\_deprecated\_model\_fallback) | If true, requests that use a deprecated model ID are transparently retried with the recommended replacement model instead of returning a 404 error. Disable if you want deprecated model IDs to fail explicitly so clients are forced to migrate. Default to true. | `bool` | `null` | no |
| <a name="input_aws_bedrock_deprecated_models"></a> [aws\_bedrock\_deprecated\_models](#input\_aws\_bedrock\_deprecated\_models) | Additional deprecated model ID mappings, merged with the built-in deprecation registry at startup. User-provided entries take precedence over built-in ones.<br/><br/>Keys are deprecated model IDs, values are the recommended replacement model IDs.<br/><br/>Example: { "my-old-model-v1" = "my-new-model-v2" } | `map(string)` | `null` | no |
| <a name="input_aws_bedrock_guardrail_identifier"></a> [aws\_bedrock\_guardrail\_identifier](#input\_aws\_bedrock\_guardrail\_identifier) | Amazon Bedrock Guardrails ID. | `string` | `null` | no |
| <a name="input_aws_bedrock_guardrail_trace"></a> [aws\_bedrock\_guardrail\_trace](#input\_aws\_bedrock\_guardrail\_trace) | Amazon Bedrock Guardrails trace setting: disabled, enabled, or enabled\_full. | `string` | `null` | no |
| <a name="input_aws_bedrock_guardrail_version"></a> [aws\_bedrock\_guardrail\_version](#input\_aws\_bedrock\_guardrail\_version) | Amazon Bedrock Guardrails version. | `string` | `null` | no |
| <a name="input_aws_bedrock_legacy"></a> [aws\_bedrock\_legacy](#input\_aws\_bedrock\_legacy) | If true, allow legacy Bedrock models to be used. Default to false. | `bool` | `null` | no |
| <a name="input_aws_bedrock_marketplace_auto_subscribe"></a> [aws\_bedrock\_marketplace\_auto\_subscribe](#input\_aws\_bedrock\_marketplace\_auto\_subscribe) | If true, allow the server to automatically subscribe to new models in the AWS Marketplace. Default to true. | `bool` | `null` | no |
| <a name="input_aws_bedrock_max_retries"></a> [aws\_bedrock\_max\_retries](#input\_aws\_bedrock\_max\_retries) | Maximum number of retries for Bedrock invocations. When region routing is enabled, retries cycle through all available regions. Default to 9. | `number` | `null` | no |
| <a name="input_aws_bedrock_model_arn_mapping"></a> [aws\_bedrock\_model\_arn\_mapping](#input\_aws\_bedrock\_model\_arn\_mapping) | Map standard model IDs to custom inference profile or prompt router ARNs. This allows server administrators to override the default cross-region inference profiles with custom application inference profiles, cross-region inference profiles, or prompt routers.<br/><br/>Supported ARN types:<br/>- Cross-region inference profile: arn:aws:bedrock:REGION:ACCOUNT:inference-profile/ID<br/>- Application inference profile: arn:aws:bedrock:REGION:ACCOUNT:application-inference-profile/ID<br/>- Prompt router: arn:aws:bedrock:REGION:ACCOUNT:default-prompt-router/ID<br/><br/>Example: {<br/>  "anthropic.claude-3-5-sonnet-20241022-v2:0" = "arn:aws:bedrock:us-east-1:123456789012:application-inference-profile/my-custom-profile"<br/>  "anthropic.claude-3-5-haiku-20241022-v1:0" = "arn:aws:bedrock:us-east-1:123456789012:default-prompt-router/my-router"<br/>} | `map(string)` | `null` | no |
| <a name="input_aws_bedrock_model_region_restrict"></a> [aws\_bedrock\_model\_region\_restrict](#input\_aws\_bedrock\_model\_region\_restrict) | Restrict a model to specific region(s) only. Can be used when a model provides important features only in certain regions.<br/><br/>Keys are Bedrock model IDs (or prefixes), values are ordered lists of allowed regions. When set, the model will only be available in the listed regions (intersected with the regions where it is actually available).<br/><br/>Example: { "amazon.nova-pro-v1:0" = ["us-east-1"] }<br/><br/>Use case: Nova grounding is only available in us-east-1, so restricting nova-pro to us-east-1 ensures grounding always works. | `map(list(string))` | `null` | no |
| <a name="input_aws_bedrock_region_routing"></a> [aws\_bedrock\_region\_routing](#input\_aws\_bedrock\_region\_routing) | Automatic region routing strategy for Bedrock invocations. Distributes requests across configured regions to handle quota limits and regional unavailability. Strategies: 'disabled' (no routing), 'ordered' (try regions in configured order, default), 'lowest\_latency' (prefer region with lowest measured latency), 'round\_robin' (distribute evenly, incompatible with prompt caching). Requires at least 2 regions in aws\_bedrock\_regions. | `string` | `null` | no |
| <a name="input_aws_bedrock_region_routing_max_quota_backoff_seconds"></a> [aws\_bedrock\_region\_routing\_max\_quota\_backoff\_seconds](#input\_aws\_bedrock\_region\_routing\_max\_quota\_backoff\_seconds) | Hard ceiling in seconds on the exponential quota backoff for a single region. Quota backoff doubles on each consecutive error; this value caps how high it can grow. Only effective when aws\_bedrock\_region\_routing is not 'disabled'. Default to 3600 (1 hour). | `number` | `null` | no |
| <a name="input_aws_bedrock_region_routing_quota_backoff_seconds"></a> [aws\_bedrock\_region\_routing\_quota\_backoff\_seconds](#input\_aws\_bedrock\_region\_routing\_quota\_backoff\_seconds) | Seconds to avoid a region after receiving a quota/throttling error. Only effective when aws\_bedrock\_region\_routing is not 'disabled'. Default to 60. | `number` | `null` | no |
| <a name="input_aws_bedrock_region_routing_quota_stale_factor"></a> [aws\_bedrock\_region\_routing\_quota\_stale\_factor](#input\_aws\_bedrock\_region\_routing\_quota\_stale\_factor) | Multiplier applied to the max quota backoff to compute the stale-error threshold. If the most recent quota error for a region is older than (max\_quota\_backoff * factor) seconds, the consecutive-error counter is reset. Only effective when aws\_bedrock\_region\_routing is not 'disabled'. Default to 2. | `number` | `null` | no |
| <a name="input_aws_bedrock_region_routing_unavailable_backoff_seconds"></a> [aws\_bedrock\_region\_routing\_unavailable\_backoff\_seconds](#input\_aws\_bedrock\_region\_routing\_unavailable\_backoff\_seconds) | Seconds to avoid a region after receiving an unavailability error. Only effective when aws\_bedrock\_region\_routing is not 'disabled'. Default to 30. | `number` | `null` | no |
| <a name="input_aws_bedrock_regions"></a> [aws\_bedrock\_regions](#input\_aws\_bedrock\_regions) | List of AWS regions where Bedrock AI models are available. Default to the current region. | `list(string)` | `null` | no |
| <a name="input_aws_comprehend_region"></a> [aws\_comprehend\_region](#input\_aws\_comprehend\_region) | AWS region for Comprehend language detection service. Default to first var.aws\_bedrock\_regions region or the current region. | `string` | `null` | no |
| <a name="input_aws_connect_timeout"></a> [aws\_connect\_timeout](#input\_aws\_connect\_timeout) | Timeout in seconds for establishing a connection to an AWS service endpoint. Keeping this value short allows fast failover to another region when a connection cannot be established. Default to 5. | `number` | `null` | no |
| <a name="input_aws_max_pool_connections"></a> [aws\_max\_pool\_connections](#input\_aws\_max\_pool\_connections) | Maximum number of concurrent HTTP connections per AWS service client. Each AWS service client (per region) maintains its own connection pool up to this limit. Increase if you observe connection pool exhaustion under high concurrency. Default to 50. | `number` | `null` | no |
| <a name="input_aws_polly_region"></a> [aws\_polly\_region](#input\_aws\_polly\_region) | AWS region for Polly text-to-speech service. Default to first var.aws\_bedrock\_regions region or the current region. | `string` | `null` | no |
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
| <a name="input_aws_transcribe_region"></a> [aws\_transcribe\_region](#input\_aws\_transcribe\_region) | AWS region for Transcribe speech-to-text service. Default to first var.aws\_bedrock\_regions region or the current region. | `string` | `null` | no |
| <a name="input_aws_transcribe_s3_bucket"></a> [aws\_transcribe\_s3\_bucket](#input\_aws\_transcribe\_s3\_bucket) | AWS S3 bucket name for temporary file storage during transcription. Defaults to aws\_s3\_bucket if not specified. | `string` | `null` | no |
| <a name="input_aws_translate_region"></a> [aws\_translate\_region](#input\_aws\_translate\_region) | AWS region for Translate text translation service. Default to first var.aws\_bedrock\_regions region or the current region. | `string` | `null` | no |
| <a name="input_cloudwatch_logs_retention_in_days"></a> [cloudwatch\_logs\_retention\_in\_days](#input\_cloudwatch\_logs\_retention\_in\_days) | Cloudwatch logs retention in days. Applies to every log group this module and its child modules create, including the Container Insights performance log group. Security Hub: CloudWatch.16 (CloudWatch log groups should be retained for a specified time period) requires at least 365 days by default — default 365 = pass; lowering it fails this control. | `number` | `365` | no |
| <a name="input_compliance_vpc_endpoints_enabled"></a> [compliance\_vpc\_endpoints\_enabled](#input\_compliance\_vpc\_endpoints\_enabled) | If true, add the interface VPC endpoints for ECR API, ECR Docker Registry, Systems Manager, SSM Incident Manager Contacts and SSM Incident Manager. Enable only if you have high compliance requirements — each interface endpoint adds cost. Security Hub: EC2.55/EC2.56/EC2.57/EC2.58/EC2.60 — default false = fail; set to true to pass. | `bool` | `false` | no |
| <a name="input_container_insight"></a> [container\_insight](#input\_container\_insight) | Container insight configuration. Valid values: 'enhanced', 'enabled', 'disabled'. Default to 'enabled'. Security Hub: ECS.12 (ECS clusters should use Container Insights) — default 'enabled' = pass; setting 'disabled' fails this control. | `string` | `"enabled"` | no |
| <a name="input_cors_allow_origins"></a> [cors\_allow\_origins](#input\_cors\_allow\_origins) | List of origins allowed to make cross-origin requests (CORS). Use ['*'] to allow all origins. Default to no CORS headers. | `list(string)` | `null` | no |
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
| <a name="input_version_to_deploy"></a> [version\_to\_deploy](#input\_version\_to\_deploy) | Container image version tag from AWS Marketplace. Leave unset to automatically use the latest stable version. Only override for testing or rollback purposes. | `string` | `"1.12.0"` | no |
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
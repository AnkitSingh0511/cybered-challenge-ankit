# CyberEd Challenge
## Multi-Tenant Container Platform on AWS ECS Fargate

---

## Overview

This project provisions a production-grade, multi-tenant container platform
on AWS using Terraform. Each student receives a fully isolated environment —
a dedicated subnet, security group, ECR repository, ECS task, IAM role, and
CloudWatch log group. No student can see, reach, or interfere with another.

| Property | Value |
|---|---|
| Candidate | candidate-002 |
| Region | ap-south-1 (Mumbai) |
| Stack | AWS ECS Fargate + ECR + VPC + CloudWatch + AWS Budgets |
| IaC | Terraform ~> 1.15.0 / AWS Provider ~> 6.0.0 |
| Image | nginx (default) / kasmweb/desktop (switchable via tfvars) |
| Budget Cap | $50 USD/month |

---

## Architecture Summary

```
Internet
    │
    │  Student-01: http://<public-ip>:80  or  https://<public-ip>:6901
    │  Student-02: http://<public-ip>:80  or  https://<public-ip>:6901
    │
┌───▼──────────────────────────────────────────────────────────────────┐
│  Internet Gateway: cybered-candidate-002-igw                         │
│  VPC: cybered-candidate-002-vpc (10.0.0.0/16)                        │
│                                                                      │
│  ┌───────────────────────────┐  ┌───────────────────────────┐        │
│  │ Subnet: 10.0.1.16/28      │  │ Subnet: 10.0.1.32/28      │        │
│  │ cybered-candidate-002-    │  │ cybered-candidate-002-    │        │
│  │ subnet-student-01         │  │ subnet-student-02         │        │
│  │                           │  │                           │        │
│  │  SG: sg-student-01        │  │  SG: sg-student-02        │        │
│  │  Inbound:                 │  │  Inbound:                 │        │
│  │    :80   ← auth-ip-01/32  │  │    :80   ← auth-ip-02/32  │        │
│  │    :6901 ← auth-ip-01/32  │  │    :6901 ← auth-ip-02/32  │        │
│  │  Outbound:                │  │  Outbound:                │        │
│  │    :80  → 0.0.0.0/0       │  │    :80  → 0.0.0.0/0       │        │
│  │    :443 → 0.0.0.0/0       │  │    :443 → 0.0.0.0/0       │        │
│  │    :6379→ cache-sg only   │  │    :6379→ cache-sg only   │        │
│  │                           │  │                           │        │
│  │  ┌───────────────────┐    │  │  ┌───────────────────┐    │        │
│  │  │  ECS Fargate Task │    │  │  │  ECS Fargate Task │    │        │
│  │  │  nginx / kasmweb  │    │  │  │  nginx / kasmweb  │    │        │
│  │  │  1 vCPU / 2 GB    │    │  │  │  1 vCPU / 2 GB    │    │        │
│  │  │  Public IP ✅    │    │  │  │  Public IP ✅     │    │        │
│  │  └───────────────────┘    │  │  └───────────────────┘    │        │
│  └───────────────────────────┘  └───────────────────────────┘        │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ Cache Subnet: 10.0.1.0/28 — Reserved (ElastiCache MVP phase) │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Reserved block: 10.0.0.0/24 (future use — not provisioned)          │
└──────────────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
ECR: cybered-candidate-002-ecr-student-01    ECR: cybered-candidate-002-ecr-student-02
Private — pull via exec role only            Private — pull via exec role only
```

---

## Repository Structure

```
cybered-challenge-ankit/
├── main.tf                   # Root orchestration — module calls only
├── variables.tf              # Input variables
├── outputs.tf                # Operational outputs
├── locals.tf                 # Sanitization engine + computed values
├── versions.tf               # Provider config + default tags
├── backend.tf                # S3 remote state configuration
├── terraform.tfvars          # Variable values (student IDs + IPs)
├── .gitignore
├── .github/
│   └── workflows/
│       └── terraform.yml     # GitOps CI/CD pipeline
├── docs/
│   ├── architecture.md       # Detailed architecture deep-dive + diagrams
│   ├── DEPLOYMENT.md         # Step-by-step deployment guide
│   └── TROUBLESHOOTING.md    # Troubleshooting runbook
└── modules/
    ├── budget/               # AWS Budgets — $50 cap, 3 alerts
    ├── networking/           # VPC, subnets, IGW, route tables, SGs
    ├── iam/                  # IAM roles and inline policies
    ├── cloudwatch/           # Per-student log groups (3-day retention)
    ├── ecr/                  # Private ECR repos + push_image.sh
    │   └── scripts/
    │       └── push_image.sh
    ├── ecs/                  # ECS cluster, task definitions, services
    └── cache/                # ElastiCache Valkey (MVP phase — deferred)
```

---

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Terraform | `~> 1.15.0` | Infrastructure provisioning |
| AWS CLI | `>= 2.0` | AWS API access + verification |
| Docker Desktop | Latest | Image pull + push via push_image.sh |
| Infracost | Latest | Cost projection before apply |

---

## Quick Start

```bash
# 1. Clone repository
git clone <repo-url>
cd cybered-challenge-ankit

# 2. Set student IPs in terraform.tfvars

# 3. Initialize
terraform init

# 4. Plan and apply
terraform plan
terraform apply
```

Full instructions → [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md)

---

## Key Design Decisions

| Decision | Choice | Reason |
|---|---|---|
| Subnet per student | `/28` public | Smallest valid size, no NAT needed |
| Security group | One per student | Zero-trust enforcement |
| ECR repository | One per student | Cross-tenant image access prevention |
| IAM task role | One per student | Least-privilege app-level permissions |
| Capacity provider | `FARGATE_SPOT` (default) | 70% cost saving during testing |
| Log retention | 3 days | Minimum per spec, cost minimization |
| Image push | `terraform_data` + `push_image.sh` | Automated within `terraform apply` |
| State locking | S3 native `use_lockfile=true` | No DynamoDB needed (TF 1.10+) |

---

## Tags Applied to All Resources

| Key | Value | Scope |
|---|---|---|
| `project` | `cybered-candidate-002` | All resources (provider default_tags) |
| `managed_by` | `terraform` | All resources (provider default_tags) |
| `environment` | `dev` | All resources (provider default_tags) |
| `candidate_id` | `candidate-002` | All resources (provider default_tags) |
| `owner` | `{student-id}` | Per-student resources (resource-level) |

---

## Estimated Cost

| Resource | Config | Estimate |
|---|---|---|
| ECS Fargate SPOT | 1 vCPU, 2 GB, per student | ~$0.05/hr |
| ECR Storage | ~50 MB nginx image | ~$0.01/month |
| CloudWatch Logs | 3-day retention | ~$0.01/day |
| VPC / IGW / Subnets | — | Free |
| AWS Budgets | — | Free |
| **Total (2 students, 8 hrs)** | | **< $1.00** |

Budget hard cap enforced at **$50/month** via `aws_budgets_budget`.
Three progressive alerts at 50%, 80%, and 100% via pre-existing SNS topic.

---

## Documentation

| Document | Purpose |
|---|---|
| [docs/architecture.md](./docs/architecture.md) | Detailed architecture, module breakdown, IAM matrix |
| [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md) | Step-by-step deployment guide |
| [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) | CLI-only troubleshooting runbook |
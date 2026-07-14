# Architecture Deep-Dive
## CyberEd Challenge

---

## 1. Network Architecture

### VPC Layout

```
VPC: 10.0.0.0/16 (cybered-candidate-002-vpc)
│
├── 10.0.0.0/24     Reserved — future use (not provisioned in Terraform)
│
└── 10.0.1.0/24     Workload + Cache space
    │
    ├── 10.0.1.0/28    Cache subnet (cybered-candidate-002-subnet-cache)
    │                  Reserved for ElastiCache Valkey — MVP phase
    │
    ├── 10.0.1.16/28   Student-01 subnet (cybered-candidate-002-subnet-student-01)
    ├── 10.0.1.32/28   Student-02 subnet (cybered-candidate-002-subnet-student-02)
    ├── 10.0.1.48/28   Student-03 subnet (auto-computed on add)
    └── ...            Up to student-13 before exhausting the /24
```

CIDR computation (Terraform):

```hcl
subnet_cidr = cidrsubnet("10.0.1.0/24", 4, idx + 1)
# idx=0 → slot 1 → 10.0.1.16/28  (slot 0 = cache, reserved)
# idx=1 → slot 2 → 10.0.1.32/28
# idx=2 → slot 3 → 10.0.1.48/28
```

### Routing

```
All subnets → ONE shared public route table (cybered-candidate-002-rt-public)
Route:          0.0.0.0/0 → cybered-candidate-002-igw

Why one route table:
  All subnets have identical routing needs (internet via IGW).
  Zero-trust isolation is enforced by security groups, not routing.
  Multiple route tables add complexity with zero security benefit.
```

### Zero-Trust Network Isolation

Three independent layers enforce isolation:

```
Layer 1 — Dedicated Subnet per Student
  Each student has their own /28 CIDR block.
  No shared L2 broadcast domain between students.

Layer 2 — Dedicated Security Group per Student
  Inbound:  Only authorized_ip/32 on ports 80 and 6901
  Outbound: Only ports 80, 443 to internet + port 6379 to cache SG
            NO rule allowing egress to 10.0.0.0/16 (VPC CIDR)

Layer 3 — Per-Student ECR Repository
  Each repo has a resource policy allowing only that student's
  execution role to pull. Cross-tenant image access is denied
  at the AWS resource policy level.
```

Isolation proof — for Student-01 to reach Student-02:

```
Student-01 task sends packet to 10.0.1.32/x (Student-02 subnet)
    ↓
Student-01 SG egress: no rule for 10.0.0.0/16 → PACKET DROPPED
    ↓ (even if somehow forwarded)
Student-02 SG ingress: only allows auth-ip-02/32 on :80/:6901 → PACKET DROPPED

Two independent drop points. Both must simultaneously fail for isolation to break.
```

### Security Group Rules Matrix

Student security group (one per student):

```
Direction  Protocol  Port   Source / Destination         Purpose
─────────────────────────────────────────────────────────────────────
Inbound    TCP       80     authorized_ip/32             HTTP desktop/webserver
Inbound    TCP       6901   authorized_ip/32             KasmWeb HTTPS UI
Outbound   TCP       80     0.0.0.0/0                   Package updates
Outbound   TCP       443    0.0.0.0/0                   ECR pull, AWS APIs
Outbound   TCP       6379   cache-sg-id (ref by SG ID)  ElastiCache Valkey
```

Cache security group (shared, static):

```
Direction  Protocol  Port   Source / Destination         Purpose
─────────────────────────────────────────────────────────────────────
Inbound    TCP       6379   student-sg-id (per student)  Redis connections
Outbound   —         —      —                            None (cache never initiates)
```

---

## 2. Module Architecture

```
Root (main.tf)
├── module.budget        → aws_budgets_budget
│                           3 alerts: 50% / 80% / 100%
│                           SNS: pre-existing topic (reference only)
│
├── module.networking    → aws_vpc
│                          aws_internet_gateway
│                          aws_subnet (per-student + cache)
│                          aws_route_table + aws_route
│                          aws_route_table_association (per subnet)
│                          aws_security_group (per-student + cache)
│                          aws_vpc_security_group_ingress_rule (per student)
│                          aws_vpc_security_group_egress_rule (per student)
│
├── module.iam           → aws_iam_role (shared execution + per-student task)
│                          aws_iam_role_policy_attachment (managed policy)
│                          aws_iam_role_policy (scoped inline policies)
│
├── module.cloudwatch    → aws_cloudwatch_log_group (per student, 3-day retention)
│                          ⏸ Pending IAM permissions — commented out in ECS
│
├── module.ecr           → aws_ecr_repository (per student, IMMUTABLE)
│                          aws_ecr_lifecycle_policy (per repo)
│                          aws_ecr_repository_policy (per repo)
│                          terraform_data → push_image.sh (per student)
│
├── module.ecs           → aws_ecs_cluster (shared)
│                          aws_ecs_cluster_capacity_providers
│                          aws_ecs_task_definition (per student)
│                          aws_ecs_service (per student)
│
└── module.cache         → ElastiCache Valkey — DEFERRED (MVP phase)
```

### Module Dependency Graph

```
versions.tf (provider, default_tags)
      │
      ▼
module.budget          module.networking
(no dependencies)      (no dependencies)
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
          module.iam   module.cloudwatch  (networking outputs)
              │               │               │
              └───────────────┼───────────────┘
                              ▼
                         module.ecr
                         (needs iam.execution_role_arn)
                              │
                              ▼
                         module.ecs
                         (needs networking + iam + cloudwatch + ecr)
```

---

## 3. IAM Architecture

### Role Inventory

```
Role: cybered-candidate-002-exec-role
  Type:    Shared (one per cluster)
  Path:    /cybered-assessment/candidate-002/
  Boundary: CyberEdAssessmentBoundary-candidate-002
  Trust:   ecs-tasks.amazonaws.com + aws:SourceAccount condition
  Used by: ECS agent (Fargate infrastructure layer)
  Purpose: Pull ECR images, write CloudWatch logs
  Policies:
    - AmazonECSTaskExecutionRolePolicy (AWS managed)
    - Inline: ecr:Get* + ecr:Batch* → cybered-candidate-002-* repos only
    - Inline: logs:CreateLogStream + logs:PutLogEvents → /cybered-candidate-002/* only

Role: cybered-candidate-002-task-role-{student-id}
  Type:    Per-student (one per student)
  Path:    /cybered-assessment/candidate-002/
  Boundary: CyberEdAssessmentBoundary-candidate-002
  Trust:   ecs-tasks.amazonaws.com + aws:SourceAccount condition
  Used by: Application code running inside the container
  Purpose: Write to that student's specific log group only
  Policies:
    - Inline: logs:CreateLogStream + logs:PutLogEvents
              → /cybered-candidate-002/{student-id} only
              → NOT any other student's log group
```

### Permissions Boundary

```
Every role has attached:
  arn:aws:iam::150105760360:policy/CyberEdAssessmentBoundary-candidate-002

This is a hard ceiling. Even if AdministratorAccess were attached to a role,
the boundary limits what the role can actually do. The boundary is set by the
assessment environment and cannot be removed or modified.

IAM evaluation order:
  1. Check boundary permits the action
  2. Check identity policy permits the action
  3. Check resource policy permits the action (for ECR)
  All three must allow — any deny is final.
```

### Confused Deputy Protection

```hcl
condition {
  test     = "StringEquals"
  variable = "aws:SourceAccount"
  values   = [account_id]
}
```

Restricts role assumption to ECS tasks originating from our specific account.
Prevents any ECS task in any other AWS account from assuming our roles even
if they know the ARN.

---

## 4. ECR Image Factory

### Flow

```
Docker Hub                  Local Machine / GHA Runner          AWS ECR (Private)
(Public)                    (terraform apply)                   (ap-south-1)

nginx:latest           →    push_image.sh:
                            1. Validate env vars + tooling
                            2. ECR auth (aws ecr get-login-password)
                            3. docker pull nginx:latest
                            4. docker tag → ECR_REPO_URL:student-id
                            5. docker push → ECR repo
                            6. Verify image in ECR (aws ecr describe-images)
                            7. trap cleanup → docker rmi
                                                  ↓
                                         ECS Fargate pulls
                                         via execution role
                                         (ECR repo policy enforces
                                          per-student access only)
```

### Per-Student ECR Repository Policy

```json
{
  "Statement": [{
    "Sid": "AllowExecutionRolePull",
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::150105760360:role/cybered-assessment/candidate-002/cybered-candidate-002-exec-role"
    },
    "Action": [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
  }]
}
```

Student-01's repo only lists the shared execution role as principal.
No other role or principal can pull from it.

---

## 5. ECS Task Architecture

### Per-Student Task Definition

```
Family:           cybered-candidate-002-task-{student-id}
CPU:              1024 (1 vCPU)
Memory:           2048 (2 GB)
Network mode:     awsvpc
Launch type:      FARGATE / FARGATE_SPOT (var.fargate_capacity_provider)
Execution role:   cybered-candidate-002-exec-role (shared)
Task role:        cybered-candidate-002-task-role-{student-id} (per-student)

Container:
  Image:          {ecr-url}/cybered-candidate-002-ecr-{student-id}:{student-id}
  Port:           80 (HTTP), 6901 (KasmWeb HTTPS)
  Health check:   curl -f http://localhost:6901/ || exit 1
  Start period:   120 seconds
  Env vars:       CACHE_HOST=placeholder (updated in MVP cache phase)
                  CACHE_PORT=6379
  Log driver:     awslogs → /cybered-candidate-002/{student-id}
                  ⏸ Commented out pending CloudWatch permissions
```

### Per-Student ECS Service

```
Name:              cybered-candidate-002-svc-{student-id}
Desired count:     1 (one desktop per student)
Subnet:            student-specific /28 subnet
Security group:    student-specific SG
Assign public IP:  ENABLED (required — no NAT Gateway)
Health grace:      120 seconds
```

---

## 6. Input Sanitization

Raw student IDs are sanitized before use in any AWS resource name:

```hcl
id = replace(replace(lower(s.id), " ", "-"), "/[^a-z0-9-]/", "")
```

Transformation examples:

```
"student-01"   → "student-01"    (no change needed)
"Alice Smith!" → "alice-smith"   (lower + space→hyphen + strip !)
"Bob@99"       → "bob-99"        (lower + strip @)
"John_Doe"     → "johndoe"       (lower + strip _)
```

Every AWS resource name, subnet CIDR, security group, and ECR repo
uses the sanitized ID — never the raw input.

---

## 7. State Management

```
Backend:    S3 (pre-existing, provisioned by assessment team)
Bucket:     cybered-assessment-tfstate-150105760360-ap-south-1
Key:        candidates/candidate-002/terraform.tfstate
Region:     ap-south-1
Encryption: AES-256 server-side encryption
Locking:    use_lockfile = true (S3 native, Terraform 1.10+)

Locking mechanism:
  On terraform plan/apply → .terraform.tfstate.lock created in S3
  On completion → lock file removed
  Concurrent runs blocked until lock is released
  No DynamoDB table needed (removed requirement in TF 1.10+)
```

---

## 8. GitOps Pipeline

```
Pull Request → master
      │
      ▼
  [terraform-plan]
  checkout → setup TF + Docker → assume IAM role
  → tf init → tf fmt check → tf validate → tf plan
  → save plan artifact → post results to PR comment
      │
      ▼ (on merge to master)
  [infracost-report]
  download artifact → infracost breakdown
  → post cost report to workflow summary
      │
      ▼
  [manual-approval]
  targets 'production' GitHub Environment
  → PAUSES — required reviewer must approve
      │
      ▼ (after approval)
  [terraform-apply]
  download approved plan artifact → assume IAM role
  → tf init → chmod push_image.sh → tf apply (saved plan)
  → verify ECS stable → output desktop URLs
```
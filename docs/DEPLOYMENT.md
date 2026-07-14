# Deployment Guide
## CyberEd Challenge

All steps are CLI-only. No AWS Console access required.

---

## Prerequisites

```bash
# Verify all tools before starting
terraform version
# Expected: Terraform v1.15.x

aws --version
# Expected: aws-cli/2.x.x

docker info
# Expected: Docker daemon running, no errors

aws sts get-caller-identity --region ap-south-1
# Expected: Account: 150105760360
```

---

## Step 1 — Clone Repository

```bash
git clone <repository-url>
cd cybered-challenge-ankit
```

---

## Step 2 — Configure Student Inputs

Edit `terraform.tfvars`:

```hcl
students = [
  {
    id            = "student-01"
    authorized_ip = "1.2.3.4/32"    # Replace with real authorized IP
  },
  {
    id            = "student-02"
    authorized_ip = "5.6.7.8/32"    # Replace with real authorized IP
  }
]

# FARGATE_SPOT for testing (70% cheaper, interruption possible)
# FARGATE for live demo (on-demand, no interruption)
fargate_capacity_provider = "FARGATE_SPOT"

log_retention_days  = 3
budget_limit_amount = "50.0"
```

**To add a student**, append to the list and run `terraform apply`.
Terraform automatically provisions all isolation resources for the new student.
Existing environments are untouched.

**To remove a student**, delete their entry and run `terraform apply`.
Terraform destroys only that student's resources.

---

## Step 3 — Initialize Terraform

```bash
terraform init
```

Expected output:

```
Initializing the backend...
Successfully configured the backend "s3"!
Initializing modules...
- budget in modules/budget
- networking in modules/networking
- iam in modules/iam
- cloudwatch in modules/cloudwatch
- ecr in modules/ecr
- ecs in modules/ecs
Terraform has been successfully initialized!
```

---

## Step 4 — Validate Configuration

```bash
# Check formatting
terraform fmt -recursive -check

# Validate HCL syntax and types
terraform validate
# Expected: Success. The configuration is valid.
```

---

## Step 5 — Cost Projection (Infracost)

Run before every apply to verify projected cost is within $50:

```bash
terraform plan -out=tfplan
terraform show -json tfplan > plan.json
infracost breakdown --path plan.json --format table
```

Review the projected monthly cost. If it exceeds $50, review
resource configuration before proceeding.

---

## Step 6 — Plan

```bash
terraform plan
```

Review carefully:
- Verify resource count matches expected
- Verify student IDs are correctly sanitized in resource names
- Verify no unexpected deletions of existing resources

---

## Step 7 — Apply

```bash
terraform apply
```

Type `yes` when prompted.

**What happens during apply (in order):**

```
1. module.budget       → $50 guardrail created first
2. module.networking   → VPC, subnets, IGW, route tables, security groups
3. module.iam          → IAM roles with permissions boundary on all
4. module.cloudwatch   → Log groups (requires CloudWatch permissions)
5. module.ecr          → Private repos created
                          push_image.sh runs per student:
                          pulls nginx:latest → tags → pushes to ECR → verifies → cleanup
6. module.ecs          → Cluster + task definitions + services started
                          Tasks reach RUNNING state in ~2-3 minutes
```

> Allow 3-5 minutes for `push_image.sh` to complete per student.
> ECS tasks take 2-3 additional minutes to reach RUNNING state.

---

## Step 8 — Wait for Services to Stabilize

```bash
aws ecs wait services-stable \
  --cluster cybered-candidate-002-cluster \
  --services cybered-candidate-002-svc-student-01 cybered-candidate-002-svc-student-02 \
  --region ap-south-1

echo "All services stable."
```

---

## Step 9 — Retrieve Student Desktop URLs

```bash
for student in student-01 student-02; do
  TASK_ARN=$(aws ecs list-tasks \
    --cluster cybered-candidate-002-cluster \
    --service-name cybered-candidate-002-svc-$student \
    --region ap-south-1 \
    --query "taskArns[0]" \
    --output text)

  PUBLIC_IP=$(aws ecs describe-tasks \
    --cluster cybered-candidate-002-cluster \
    --tasks $TASK_ARN \
    --region ap-south-1 \
    --query "tasks[0].attachments[0].details[?name=='publicIp'].value|[0]" \
    --output text)

  echo "$student:"
  echo "  HTTP  → http://$PUBLIC_IP:80"
  echo "  KasmWeb → https://$PUBLIC_IP:6901"
done
```

---

## Step 10 — Verify Terraform Outputs

```bash
terraform output vpc_id
terraform output student_subnet_ids
terraform output student_security_group_ids
terraform output ecr_repository_urls
terraform output ecs_cluster_arn
terraform output ecs_service_names
terraform output sanitized_student_map
```

---

## Live Demo — Switch to On-Demand Fargate

Before the live demo, switch from FARGATE_SPOT to FARGATE to prevent
task interruptions mid-session:

```bash
terraform apply -var="fargate_capacity_provider=FARGATE"
```

---

## Teardown — Stop All AWS Spend

After the assessment, destroy all resources:

```bash
terraform destroy
```

Verify nothing remains:

```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=project,Values=cybered-candidate-002 \
  --region ap-south-1 \
  --query "ResourceTagMappingList[*].ResourceARN" \
  --output text
# Expected: (empty output)
```

---

## GitOps Deployment (GitHub Actions)

For CI/CD deployment via the GitHub Actions pipeline:

```
1. Push changes to a feature branch
2. Open Pull Request targeting master
   → Pipeline runs terraform plan + Infracost report automatically
   → Results posted as PR comment
3. Merge PR to master
   → Pipeline re-runs plan on merged code
   → Infracost report posted to workflow summary
   → Pipeline pauses at manual approval gate
4. Approve in GitHub Actions UI (Settings → Environments → production)
   → terraform apply runs automatically using saved plan
   → ECS health verified post-apply
   → Desktop URLs printed to workflow summary
```
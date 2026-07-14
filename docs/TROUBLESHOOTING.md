# Troubleshooting Runbook
## CyberEd Challenge

All commands are CLI-only. No AWS Console access required.

---

## Quick Diagnostic — Run First

```bash
# 1. Confirm AWS CLI auth
aws sts get-caller-identity --region ap-south-1

# 2. Check ECS service health
aws ecs describe-services \
  --cluster cybered-candidate-002-cluster \
  --services cybered-candidate-002-svc-student-01 cybered-candidate-002-svc-student-02 \
  --region ap-south-1 \
  --query "services[*].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount,Event:events[0].message}" \
  --output table

# 3. List all running tasks
aws ecs list-tasks \
  --cluster cybered-candidate-002-cluster \
  --region ap-south-1 \
  --output table

# 4. Confirm no pending Terraform changes
terraform plan
# Expected: No changes. Your infrastructure matches the configuration.
```

---

## Issue 1 — ECS Task Fails to Start

**Symptoms:** `runningCount = 0`, task keeps cycling PENDING → STOPPED,
or `pendingCount` stays at 1 for more than 5 minutes.

**Step 1 — Get stopped task stop reason:**

```bash
TASK_ARN=$(aws ecs list-tasks \
  --cluster cybered-candidate-002-cluster \
  --desired-status STOPPED \
  --region ap-south-1 \
  --query "taskArns[0]" \
  --output text)

aws ecs describe-tasks \
  --cluster cybered-candidate-002-cluster \
  --tasks $TASK_ARN \
  --region ap-south-1 \
  --query "tasks[0].{
    Status:lastStatus,
    StopCode:stopCode,
    StopReason:stoppedReason,
    ContainerReason:containers[0].reason
  }" \
  --output table
```

**Common stop reasons and fixes:**

```
Stop Reason                   Cause                          Fix
──────────────────────────────────────────────────────────────────────────
CannotPullContainerError      ECR auth or repo policy issue  See Step 2
OutOfMemoryError              Container exceeded 2 GB        Check image size
ResourceInitializationError   Cannot reach ECR/CW endpoints  Check SG egress :443
HealthCheckFailed             App not responding on :6901    See Step 3
Essential container exited    Application crash at startup   Check logs Issue 3
```

**Step 2 — Verify ECR image and repo policy:**

```bash
# Verify image exists
aws ecr list-images \
  --repository-name cybered-candidate-002-ecr-student-01 \
  --region ap-south-1 \
  --query "imageIds[*].{Tag:imageTag}" \
  --output table

# Verify repo policy allows execution role
aws ecr get-repository-policy \
  --repository-name cybered-candidate-002-ecr-student-01 \
  --region ap-south-1 \
  --query "policyText" \
  --output text
```

**Step 3 — Check health check configuration:**

```bash
aws ecs describe-task-definition \
  --task-definition cybered-candidate-002-task-student-01 \
  --region ap-south-1 \
  --query "taskDefinition.containerDefinitions[0].healthCheck" \
  --output json
```

**Step 4 — Force new deployment:**

```bash
aws ecs update-service \
  --cluster cybered-candidate-002-cluster \
  --service cybered-candidate-002-svc-student-01 \
  --force-new-deployment \
  --region ap-south-1
```

---

## Issue 2 — Cannot Access Student Desktop

**Symptoms:** Browser timeout or connection refused on
`http://<public-ip>:80` or `https://<public-ip>:6901`.

**Step 1 — Confirm task is RUNNING and get public IP:**

```bash
TASK_ARN=$(aws ecs list-tasks \
  --cluster cybered-candidate-002-cluster \
  --service-name cybered-candidate-002-svc-student-01 \
  --region ap-south-1 \
  --query "taskArns[0]" \
  --output text)

aws ecs describe-tasks \
  --cluster cybered-candidate-002-cluster \
  --tasks $TASK_ARN \
  --region ap-south-1 \
  --query "tasks[0].{
    Status:lastStatus,
    Health:healthStatus,
    PublicIP:attachments[0].details[?name=='publicIp'].value|[0],
    PrivateIP:attachments[0].details[?name=='privateIPv4Address'].value|[0]
  }" \
  --output table
```

**Step 2 — Check your current IP matches the authorized IP:**

```bash
# Get your current public IP
curl -s https://checkip.amazonaws.com

# Compare with SG inbound rules
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=cybered-candidate-002-sg-student-01" \
  --region ap-south-1 \
  --query "SecurityGroups[0].IpPermissions[*].{Protocol:IpProtocol,Port:FromPort,CIDR:IpRanges[0].CidrIp}" \
  --output table
```

If your IP has changed, update `terraform.tfvars` and reapply:

```bash
# Update authorized_ip in terraform.tfvars, then:
terraform apply
```

**Step 3 — Verify ENI has public IP and correct SG assigned:**

```bash
ENI_ID=$(aws ecs describe-tasks \
  --cluster cybered-candidate-002-cluster \
  --tasks $TASK_ARN \
  --region ap-south-1 \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value|[0]" \
  --output text)

aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_ID \
  --region ap-south-1 \
  --query "NetworkInterfaces[0].{
    PublicIP:Association.PublicIp,
    PrivateIP:PrivateIpAddress,
    SubnetId:SubnetId,
    SG:Groups[0].GroupName
  }" \
  --output table
```

---

## Issue 3 — Accessing Container Logs

**Step 1 — Verify log group exists:**

```bash
aws logs describe-log-groups \
  --log-group-name-prefix /cybered-candidate-002 \
  --region ap-south-1 \
  --query "logGroups[*].{Name:logGroupName,RetentionDays:retentionInDays}" \
  --output table
```

**Step 2 — List log streams for a student:**

```bash
aws logs describe-log-streams \
  --log-group-name /cybered-candidate-002/student-01 \
  --region ap-south-1 \
  --order-by LastEventTime \
  --descending \
  --query "logStreams[*].{Stream:logStreamName,LastEvent:lastEventTime}" \
  --output table
```

**Step 3 — Fetch latest log events:**

```bash
STREAM=$(aws logs describe-log-streams \
  --log-group-name /cybered-candidate-002/student-01 \
  --region ap-south-1 \
  --order-by LastEventTime \
  --descending \
  --query "logStreams[0].logStreamName" \
  --output text)

aws logs get-log-events \
  --log-group-name /cybered-candidate-002/student-01 \
  --log-stream-name "$STREAM" \
  --region ap-south-1 \
  --limit 50 \
  --query "events[*].{Message:message}" \
  --output text
```

**Step 4 — Tail logs in real time:**

```bash
aws logs tail /cybered-candidate-002/student-01 \
  --region ap-south-1 \
  --follow
# Ctrl+C to stop
```

---

## Issue 4 — Cache Connection Error (MVP Phase)

**Symptoms:** Application logs show `Connection refused` on `CACHE_HOST:6379`.

**Step 1 — Check ElastiCache cluster status:**

```bash
aws elasticache describe-cache-clusters \
  --region ap-south-1 \
  --query "CacheClusters[?starts_with(CacheClusterId,'cybered-candidate-002')].{
    ID:CacheClusterId,
    Status:CacheClusterStatus,
    Endpoint:CacheNodes[0].Endpoint.Address,
    Port:CacheNodes[0].Endpoint.Port
  }" \
  --output table
# Expected: Status=available
```

**Step 2 — Verify CACHE_HOST env var in task definition:**

```bash
aws ecs describe-task-definition \
  --task-definition cybered-candidate-002-task-student-01 \
  --region ap-south-1 \
  --query "taskDefinition.containerDefinitions[0].environment" \
  --output table
# CACHE_HOST must not be "placeholder" — should be real ElastiCache endpoint
```

**Step 3 — Verify cache SG accepts from student SGs:**

```bash
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=cybered-candidate-002-sg-cache" \
  --region ap-south-1 \
  --query "SecurityGroups[0].IpPermissions[*].{
    Port:FromPort,
    SourceSG:UserIdGroupPairs[0].GroupId
  }" \
  --output table
# Expected: Port=6379, one SourceSG entry per student
```

**Step 4 — Verify student SG has egress to cache SG:**

```bash
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=cybered-candidate-002-sg-student-01" \
  --region ap-south-1 \
  --query "SecurityGroups[0].IpPermissionsEgress[?FromPort==\`6379\`]" \
  --output json
# Expected: Rule present referencing cache SG ID
```

---

## Issue 5 — Terraform State Lock

**Symptoms:** `Error: Error acquiring the state lock` during plan or apply.

```bash
# Check if lock file exists
aws s3 ls \
  s3://cybered-assessment-tfstate-150105760360-ap-south-1/candidates/candidate-002/ \
  --region ap-south-1
# If .terraform.tfstate.lock present — lock is held

# Force unlock — only if previous operation is confirmed dead
# Lock ID is printed in the error message
terraform force-unlock <LOCK_ID>
```

---

## Issue 6 — Image Push Fails During terraform apply

**Symptoms:** `terraform_data.push_image` provisioner fails with
Docker or ECR authentication errors.

**Step 1 — Test ECR authentication manually:**

```bash
aws ecr get-login-password \
  --region ap-south-1 | \
  docker login \
    --username AWS \
    --password-stdin \
    150105760360.dkr.ecr.ap-south-1.amazonaws.com
# Expected: Login Succeeded
```

**Step 2 — Test Docker pull manually:**

```bash
docker pull nginx:latest
# If this fails — Docker Desktop not running or network issue
docker info
```

**Step 3 — Force re-run of push_image.sh without recreating repos:**

```bash
terraform apply \
  -replace='module.ecr.terraform_data.push_image["student-01"]' \
  -replace='module.ecr.terraform_data.push_image["student-02"]'
```

---

## Issue 7 — Budget Alert Fired

**Symptoms:** SNS notification received — spend threshold crossed.

**Step 1 — Check current month spend:**

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --region ap-south-1 \
  --query "ResultsByTime[0].Total.BlendedCost.{Amount:Amount,Unit:Unit}" \
  --output table
```

**Step 2 — Identify top spending services:**

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --region ap-south-1 \
  --query "ResultsByTime[0].Groups[*].{Service:Keys[0],Cost:Metrics.BlendedCost.Amount}" \
  --output table
```

**Step 3 — Scale down Fargate tasks immediately:**

```bash
for student in student-01 student-02; do
  aws ecs update-service \
    --cluster cybered-candidate-002-cluster \
    --service cybered-candidate-002-svc-$student \
    --desired-count 0 \
    --region ap-south-1
  echo "Scaled down: $student"
done
```

**Step 4 — Full teardown if needed:**

```bash
terraform destroy
```

---

## Resource Name Reference

```
Resource              Name Pattern
──────────────────────────────────────────────────────────────────
VPC                   cybered-candidate-002-vpc
Internet Gateway      cybered-candidate-002-igw
Route Table           cybered-candidate-002-rt-public
Student Subnet        cybered-candidate-002-subnet-{student-id}
Cache Subnet          cybered-candidate-002-subnet-cache
Student SG            cybered-candidate-002-sg-{student-id}
Cache SG              cybered-candidate-002-sg-cache
Execution Role        cybered-candidate-002-exec-role
Task Role             cybered-candidate-002-task-role-{student-id}
Log Group             /cybered-candidate-002/{student-id}
ECR Repository        cybered-candidate-002-ecr-{student-id}
ECS Cluster           cybered-candidate-002-cluster
Task Definition       cybered-candidate-002-task-{student-id}
ECS Service           cybered-candidate-002-svc-{student-id}
Budget                cybered-candidate-002-budget
```
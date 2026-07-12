# modules/iam/iam_policies.tf
# -----------------------------------------------------------------------------
# Inline policies only — no customer-managed policies (banned by spec).
#
# Execution role gets two scoped inline policies:
#   1. ECR — explicit Get* and Batch* actions scoped to our repos prefix
#   2. CloudWatch — CreateLogStream + PutLogEvents scoped to our log groups
#
# Per-student task role gets one inline policy:
#   1. CloudWatch — CreateLogStream + PutLogEvents scoped to that student's
#      log group only — not any other student's group
# -----------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Execution Role — ECR Inline Policy
# Scoped to cybered-candidate-002-* repositories only.
# ecr:GetAuthorizationToken is covered by the managed policy (cannot scope).
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "execution_ecr" {
  statement {
    sid    = "AllowScopedECRAccess"
    effect = "Allow"

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:GetLifecyclePolicy",
      "ecr:GetLifecyclePolicyPreview",
      "ecr:BatchGetImage",
      "ecr:BatchGetRepositoryScanning",
      "ecr:BatchCheckLayerAvailability",
    ]

    resources = [
      "arn:aws:ecr:${var.region}:${var.account_id}:repository/${var.prefix}-*"
    ]
  }

  statement {
    sid    = "AllowECRGetAccess"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:GetRegistryPolicy",
      "ecr:GetRegistryScanningConfiguration"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "execution_ecr" {
  name   = "${var.prefix}-exec-ecr-policy"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.execution_ecr.json
}

# ---------------------------------------------------------------------------
# Execution Role — CloudWatch Inline Policy
# Scoped to /cybered-candidate-002/* log groups only.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "execution_logs" {
  statement {
    sid    = "AllowScopedCloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/cybered-candidate-002/*",
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/cybered-candidate-002/*:log-stream:*"
    ]
  }
}

resource "aws_iam_role_policy" "execution_logs" {
  name   = "${var.prefix}-exec-logs-policy"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.execution_logs.json
}

# ---------------------------------------------------------------------------
# Per-Student Task Role — CloudWatch Inline Policy
# Scoped to that student's specific log group only.
# Student-01's task role cannot write to student-02's log group.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "task_logs" {
  for_each = var.sanitized_students

  statement {
    sid    = "AllowStudentScopedLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/${var.prefix}/${each.value.id}",
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/${var.prefix}/${each.value.id}:log-stream:*"
    ]
  }
}

resource "aws_iam_role_policy" "task_logs" {
  for_each = var.sanitized_students

  name   = "${var.prefix}-task-logs-policy-${each.value.id}"
  role   = aws_iam_role.ecs_task[each.key].id
  policy = data.aws_iam_policy_document.task_logs[each.key].json
}
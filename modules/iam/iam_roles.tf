# modules/iam/iam_roles.tf
# -----------------------------------------------------------------------------
# Two role types:
#   1. Shared ECS Task Execution Role — used by the ECS AGENT (Fargate
#      infrastructure) to pull ECR images and write CloudWatch logs.
#      One per cluster, not per student.
#
#   2. Per-Student ECS Task Role — assumed by APPLICATION CODE running
#      inside the container. Scoped to that student's resources only.
#
# ALL roles:
#   - Path:                /cybered-assessment/candidate-002/
#   - Permissions boundary: CyberEdAssessmentBoundary-candidate-002
#   - Trust policy:         ecs-tasks.amazonaws.com
# -----------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Shared trust policy document — reused by both role types
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_trust" {
  statement {
    sid     = "AllowECSTasksAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    # Condition scopes trust to our specific account only.
    # Prevents confused deputy attacks from other AWS accounts.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

# ---------------------------------------------------------------------------
# Role 1 — Shared ECS Task Execution Role
# Used by: ECS agent (Fargate infrastructure layer)
# Purpose: Pull ECR images, write logs to CloudWatch
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ecs_execution" {
  name                 = "${var.prefix}-exec-role"
  path                 = var.iam_path
  description          = "ECS task execution role for ${var.prefix}. Used by Fargate agent to pull images and write logs."
  assume_role_policy   = data.aws_iam_policy_document.ecs_trust.json
  permissions_boundary = var.permissions_boundary

  tags = {
    name = "${var.prefix}-exec-role"
  }
}

# ---------------------------------------------------------------------------
# Role 2 — Per-Student ECS Task Role
# Used by: Application code running INSIDE the container
# Purpose: Write to that student's specific CloudWatch log group only
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task" {
  for_each = var.sanitized_students

  name                 = "${var.prefix}-task-role-${each.value.id}"
  path                 = var.iam_path
  description          = "ECS task role for ${each.value.id}. Scoped to student-specific resources only."
  assume_role_policy   = data.aws_iam_policy_document.ecs_trust.json
  permissions_boundary = var.permissions_boundary

  tags = {
    name  = "${var.prefix}-task-role-${each.value.id}"
    owner = each.value.id
  }
}

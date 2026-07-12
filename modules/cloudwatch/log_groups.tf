# modules/cloudwatch/log_groups.tf
# -----------------------------------------------------------------------------
# One CloudWatch Log Group per student.
# Pre-created before ECS task definitions reference them.
# If the log group does not exist when the ECS task starts, the awslogs
# driver fails silently and the task enters a crash loop.
#
# Naming: /cybered-candidate-002/{student-id}
# Retention: 3 days (minimum per spec, maximum cost savings)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "student" {
  for_each = var.sanitized_students

  name              = "/${var.prefix}/${each.value.id}"
  retention_in_days = var.log_retention_days

  tags = {
    name  = "${var.prefix}-logs-${each.value.id}"
    owner = each.value.id
  }
}
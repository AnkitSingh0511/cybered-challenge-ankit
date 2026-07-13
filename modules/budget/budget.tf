# modules/budget/budget.tf
# -----------------------------------------------------------------------------
# AWS Budget resource with three progressive ACTUAL spend alerts.
# Budget name follows required prefix: cybered-candidate-002-*
# SNS topic is pre-existing — referenced by ARN, never created or modified.
#
# Alert thresholds:
#   50%  → $25.00  — Early warning, investigate spend
#   80%  → $40.00  — Serious warning, consider teardown
#   100% → $50.00  — Hard cap breached, immediate action required
# -----------------------------------------------------------------------------

resource "aws_budgets_budget" "assessment_budget" {
  name         = "${var.prefix}-budget"
  budget_type  = "COST"
  limit_amount = var.budget_limit_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  account_id   = var.account_id

  # ---------------------------------------------------------------------------
  # Alert 1 — 50% ($25.00) Early Warning
  # Signals that half the budget is consumed. Time to review active resources.
  # ---------------------------------------------------------------------------
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 50
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [var.budget_sns_topic_arn]
  }

  # ---------------------------------------------------------------------------
  # Alert 2 — 80% ($40.00) Serious Warning
  # Only $10 of headroom remains. Begin planning teardown of non-essential
  # resources. At this point the demo should be imminent or complete.
  # ---------------------------------------------------------------------------
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [var.budget_sns_topic_arn]
  }

  # ---------------------------------------------------------------------------
  # Alert 3 — 100% ($50.00) Hard Cap Breached
  # Immediate action required. Run terraform destroy to stop all spend.
  # AWS does not automatically stop resources when budget is breached —
  # the alert is a notification only. Manual or automated action is required.
  # ---------------------------------------------------------------------------
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [var.budget_sns_topic_arn]
  }

  provider = aws.no_tags
}
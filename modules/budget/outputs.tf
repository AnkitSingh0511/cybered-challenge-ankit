# modules/budget/outputs.tf
# -----------------------------------------------------------------------------
# Outputs from the budget module.
# -----------------------------------------------------------------------------

output "budget_name" {
  description = "Name of the AWS Budget resource monitoring the $50 cap."
  value       = aws_budgets_budget.assessment_budget.name
}

output "budget_id" {
  description = "Unique ID of the AWS Budget resource."
  value       = aws_budgets_budget.assessment_budget.id
}
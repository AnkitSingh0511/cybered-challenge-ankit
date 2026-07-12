# modules/budget/variables.tf
# -----------------------------------------------------------------------------
# Input variables for the budget module.
# All values flow from root locals and variables — no hardcoding inside module.
# -----------------------------------------------------------------------------

variable "prefix" {
  type        = string
  description = "Resource naming prefix. Must be cybered-candidate-002."
}

variable "account_id" {
  type        = string
  description = "AWS account ID. Resolved dynamically via aws_caller_identity."
}

variable "budget_limit_amount" {
  type        = string
  description = "Hard budget cap in USD as a string. e.g. 50.0"
}

variable "budget_sns_topic_arn" {
  type        = string
  description = "Pre-existing SNS topic ARN for budget alerts. Reference only — do not create or modify."
}
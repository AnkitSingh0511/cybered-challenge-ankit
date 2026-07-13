# modules/iam/variables.tf

variable "prefix" {
  type        = string
  description = "Resource naming prefix."
}

variable "iam_path" {
  type        = string
  description = "IAM path for all roles. Must be /cybered-assessment/candidate-002/"
}

variable "permissions_boundary" {
  type        = string
  description = "Permissions boundary ARN. Attached to every role without exception."
}

variable "account_id" {
  type        = string
  description = "AWS account ID for ARN construction."
}

variable "region" {
  type        = string
  description = "AWS region for ARN construction."
}

variable "sanitized_students" {
  type = map(object({
    raw_id        = string
    id            = string
    authorized_ip = string
    index         = number
    subnet_cidr   = string
  }))
  description = "Pre-sanitized student map from root locals."
}
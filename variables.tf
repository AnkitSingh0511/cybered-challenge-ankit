# variables.tf
# -----------------------------------------------------------------------------
# Root input variables.
# All sensitive values (authorized_ip) are provided via terraform.tfvars
# which is gitignored.
# -----------------------------------------------------------------------------

variable "aws_region" {
  type        = string
  description = "AWS region for all resources. Must be ap-south-1 per assessment constraints."
  default     = "ap-south-1"

  validation {
    condition     = var.aws_region == "ap-south-1"
    error_message = "Only ap-south-1 is permitted per assessment constraints."
  }
}

variable "students" {
  type = list(object({
    id            = string
    authorized_ip = string
  }))
  description = <<-EOT
    List of student objects. Each student gets a fully isolated environment.
    id            : Raw student identifier. Will be sanitized automatically
                    (lowercase, spaces → hyphens, special chars removed).
    authorized_ip : The single IP address authorized to access this student's
                    desktop. Must be in CIDR notation (e.g. "1.2.3.4/32").
  EOT

  validation {
    condition = alltrue([
      for s in var.students :
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/32$", s.authorized_ip))
    ])
    error_message = "Each authorized_ip must be a valid /32 CIDR (e.g. 1.2.3.4/32)."
  }
}

variable "fargate_capacity_provider" {
  type        = string
  description = <<-EOT
    Fargate capacity provider strategy.
    Use FARGATE_SPOT for testing/development (70% cost saving, interruption possible).
    Use FARGATE for live demo (on-demand, no interruption).
    Override at demo time: terraform apply -var="fargate_capacity_provider=FARGATE"
  EOT
  default     = "FARGATE_SPOT"

  validation {
    condition     = contains(["FARGATE", "FARGATE_SPOT"], var.fargate_capacity_provider)
    error_message = "fargate_capacity_provider must be either FARGATE or FARGATE_SPOT."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "workload_subnet_base" {
  type        = string
  description = <<-EOT
    Base CIDR for workload subnet allocation.
    Student subnets are carved from this block using cidrsubnet().
    Slot 0 (10.0.1.0/28) is reserved for cache.
    Student subnets start at slot 1 (10.0.1.16/28).
  EOT
  default     = "10.0.1.0/24"
}

variable "cache_subnet_cidr" {
  type        = string
  description = "Static CIDR for the ElastiCache subnet. Reserved for MVP cache phase."
  default     = "10.0.1.0/28"
}

variable "kasm_image" {
  type        = string
  description = "Source Docker image to pull from Docker Hub and push to ECR."
  default     = "nginx"
}

variable "kasm_image_tag" {
  type        = string
  description = "Tag of the source Docker image to pull."
  default     = "latest"
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days. Spec allows 3-7. Minimum for cost savings."
  default     = 3

  validation {
    condition     = contains([3, 5, 7], var.log_retention_days)
    error_message = "log_retention_days must be 3, 5, or 7 per assessment constraints."
  }
}

variable "budget_limit_amount" {
  type        = string
  description = "Hard budget cap in USD. Must not exceed 50 per assessment constraints."
  default     = "50.0"
}

variable "budget_sns_topic_arn" {
  type        = string
  description = "Pre-existing SNS topic ARN for budget alerts. Do not create or modify."
  default     = "arn:aws:sns:ap-south-1:150105760360:cyberedassessment-budget-alerts"
}
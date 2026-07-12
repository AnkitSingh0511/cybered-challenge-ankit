# modules/ecs/variables.tf

variable "prefix" {
  type        = string
  description = "Resource naming prefix."
}

variable "region" {
  type        = string
  description = "AWS region."
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

variable "execution_role_arn" {
  type        = string
  description = "Shared ECS task execution role ARN."
}

variable "task_role_arns" {
  type        = map(string)
  description = "Map of sanitized student ID to their ECS task role ARN."
}

variable "student_subnet_ids" {
  type        = map(string)
  description = "Map of sanitized student ID to their subnet ID."
}

variable "student_security_group_ids" {
  type        = map(string)
  description = "Map of sanitized student ID to their security group ID."
}

variable "image_uris" {
  type        = map(string)
  description = "Map of sanitized student ID to their full ECR image URI including tag."
}

variable "fargate_capacity_provider" {
  type        = string
  description = "FARGATE or FARGATE_SPOT. Override to FARGATE at live demo."
}

variable "task_cpu" {
  type        = number
  description = "Task CPU units. 1024 = 1 vCPU. KasmWeb minimum."
  default     = 1024
}

variable "task_memory" {
  type        = number
  description = "Task memory in MB. 2048 = 2GB. KasmWeb minimum."
  default     = 2048
}

# Uncomment when CloudWatch log groups are provisioned
# variable "log_group_names" {
#   type        = map(string)
#   description = "Map of sanitized student ID to their CloudWatch log group name."
# }
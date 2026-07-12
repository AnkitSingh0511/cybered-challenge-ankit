# modules/ecr/variables.tf

variable "prefix" {
  type        = string
  description = "Resource naming prefix."
}

variable "account_id" {
  type        = string
  description = "AWS account ID for repository policy ARN construction."
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
  description = "ECS task execution role ARN. Granted pull access on each repo's resource policy."
}

variable "kasm_image" {
  type        = string
  description = "Source Docker image to pull from Docker Hub."
}

variable "kasm_image_tag" {
  type        = string
  description = "Tag of the source Docker image."
}
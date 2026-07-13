# modules/cloudwatch/variables.tf

variable "prefix" {
  type        = string
  description = "Resource naming prefix."
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

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days. Valid values: 3, 5, 7."
}
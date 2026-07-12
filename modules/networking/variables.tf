# modules/networking/variables.tf

variable "prefix" {
  type        = string
  description = "Resource naming prefix."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
}

variable "cache_subnet_cidr" {
  type        = string
  description = "Static CIDR for the ElastiCache cache subnet."
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

variable "aws_region" {
  type        = string
  description = "AWS region. Used for AZ construction."
}
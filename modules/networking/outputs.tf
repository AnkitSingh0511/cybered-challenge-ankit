# modules/networking/outputs.tf

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "Internet Gateway ID."
  value       = aws_internet_gateway.main.id
}

output "student_subnet_ids" {
  description = "Map of sanitized student ID to subnet ID."
  value = {
    for k, s in var.sanitized_students :
    s.id => aws_subnet.student[k].id
  }
}

output "cache_subnet_id" {
  description = "Cache subnet ID. Used by ElastiCache subnet group in MVP phase."
  value       = aws_subnet.cache.id
}

output "student_security_group_ids" {
  description = "Map of sanitized student ID to security group ID."
  value = {
    for k, s in var.sanitized_students :
    s.id => aws_security_group.student[k].id
  }
}

output "cache_security_group_id" {
  description = "Cache security group ID. Used by ElastiCache in MVP phase."
  value       = aws_security_group.cache.id
}
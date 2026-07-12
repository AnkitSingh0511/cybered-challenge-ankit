# outputs.tf
# -----------------------------------------------------------------------------
# Root outputs — displayed after terraform apply.
# These are the primary operational reference for accessing and verifying
# the deployed infrastructure without console access.
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID for the assessment environment."
  value       = module.networking.vpc_id
}

output "student_subnet_ids" {
  description = "Map of sanitized student ID to their dedicated subnet ID."
  value       = module.networking.student_subnet_ids
}

output "student_security_group_ids" {
  description = "Map of sanitized student ID to their dedicated security group ID."
  value       = module.networking.student_security_group_ids
}

output "ecr_repository_urls" {
  description = "Map of sanitized student ID to their private ECR repository URL."
  value       = module.ecr.repository_urls
}

output "ecs_cluster_arn" {
  description = "ARN of the shared ECS cluster."
  value       = module.ecs.cluster_arn
}

output "ecs_service_names" {
  description = "Map of sanitized student ID to their ECS service name."
  value       = module.ecs.service_names
}

output "ecs_task_public_ips" {
  description = <<-EOT
    Map of sanitized student ID to their Fargate task public IP.
    Use these IPs to access student desktops:
    https://<public_ip>:6901
    Note: IPs are assigned at task launch. If empty, query via:
    aws ecs list-tasks --cluster cybered-candidate-002-cluster --region ap-south-1
  EOT
  value       = module.ecs.task_public_ips
}

# output "cloudwatch_log_group_names" {
#   description = "Map of sanitized student ID to their CloudWatch log group name."
#   value       = module.cloudwatch.log_group_names
# }

output "iam_execution_role_arn" {
  description = "ARN of the shared ECS task execution role."
  value       = module.iam.execution_role_arn
}

output "iam_task_role_arns" {
  description = "Map of sanitized student ID to their ECS task role ARN."
  value       = module.iam.task_role_arns
}

output "budget_name" {
  description = "Name of the AWS Budget resource monitoring the $50 cap."
  value       = module.budget.budget_name
}

output "sanitized_student_map" {
  description = <<-EOT
    Full sanitized student map for debugging.
    Shows raw ID → sanitized ID, subnet CIDR, and index for every student.
  EOT
  value = {
    for raw_id, s in local.sanitized_students :
    raw_id => {
      sanitized_id  = s.id
      subnet_cidr   = s.subnet_cidr
      index         = s.index
      authorized_ip = s.authorized_ip
    }
  }
}
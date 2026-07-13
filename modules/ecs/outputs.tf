# modules/ecs/outputs.tf

output "cluster_arn" {
  description = "ARN of the shared ECS cluster."
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "Name of the shared ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "service_names" {
  description = "Map of sanitized student ID to their ECS service name."
  value = {
    for k, s in var.sanitized_students :
    s.id => aws_ecs_service.student[k].name
  }
}

output "task_definition_arns" {
  description = "Map of sanitized student ID to their task definition ARN."
  value = {
    for k, s in var.sanitized_students :
    s.id => aws_ecs_task_definition.student[k].arn
  }
}

# ---------------------------------------------------------------------------
# task_public_ips — NOTE: Fargate public IPs are assigned at task launch
# and are not available as Terraform outputs. Query via CLI after apply:
#
# TASK_ARN=$(aws ecs list-tasks \
#   --cluster cybered-candidate-002-cluster \
#   --region ap-south-1 \
#   --query "taskArns[0]" --output text)
#
# aws ecs describe-tasks \
#   --cluster cybered-candidate-002-cluster \
#   --tasks $TASK_ARN \
#   --region ap-south-1 \
#   --query "tasks[0].attachments[0].details[?name=='publicIp'].value" \
#   --output text
# ---------------------------------------------------------------------------
output "task_public_ips" {
  description = "Public IPs are assigned at task launch — not available as TF outputs. See CLI commands in output description."
  value       = "Query via CLI — see output description for commands."
}
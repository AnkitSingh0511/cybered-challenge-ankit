# modules/iam/outputs.tf

output "execution_role_arn" {
  description = "ARN of the shared ECS task execution role."
  value       = aws_iam_role.ecs_execution.arn
}

output "execution_role_name" {
  description = "Name of the shared ECS task execution role."
  value       = aws_iam_role.ecs_execution.name
}

output "task_role_arns" {
  description = "Map of sanitized student ID to their ECS task role ARN."
  value = {
    for k, s in var.sanitized_students :
    s.id => aws_iam_role.ecs_task[k].arn
  }
}

output "task_role_names" {
  description = "Map of sanitized student ID to their ECS task role name."
  value = {
    for k, s in var.sanitized_students :
    s.id => aws_iam_role.ecs_task[k].name
  }
}
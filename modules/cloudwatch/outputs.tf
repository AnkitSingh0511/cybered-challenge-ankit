# modules/cloudwatch/outputs.tf

output "log_group_names" {
  description = "Map of sanitized student ID to their CloudWatch log group name."
  value = {
    for k, s in var.sanitized_students :
    s.id => aws_cloudwatch_log_group.student[k].name
  }
}

output "log_group_arns" {
  description = "Map of sanitized student ID to their CloudWatch log group ARN."
  value = {
    for k, s in var.sanitized_students :
    s.id => aws_cloudwatch_log_group.student[k].arn
  }
}
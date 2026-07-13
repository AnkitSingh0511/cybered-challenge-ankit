# modules/ecr/outputs.tf

output "repository_urls" {
  description = "Map of sanitized student ID to their ECR repository URL."
  value = {
    for k, s in var.sanitized_students :
    s.id => aws_ecr_repository.student[k].repository_url
  }
}

output "repository_names" {
  description = "Map of sanitized student ID to their ECR repository name."
  value = {
    for k, s in var.sanitized_students :
    s.id => aws_ecr_repository.student[k].name
  }
}

output "image_uris" {
  description = "Map of sanitized student ID to their full ECR image URI including tag."
  value = {
    for k, s in var.sanitized_students :
    s.id => "${aws_ecr_repository.student[k].repository_url}:${s.id}"
  }
}
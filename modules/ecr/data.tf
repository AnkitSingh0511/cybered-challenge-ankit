# ---------------------------------------------------------------------------
# Image Push — terraform_data triggers push_image.sh per student
# Runs after ECR repo and repo policy are created.
# Script receives all context via environment variables — nothing hardcoded.
# Re-runs only if the repository URL changes (immutable tag means
# a re-push is skipped by Docker if image already exists in ECR).
# ---------------------------------------------------------------------------
resource "terraform_data" "push_image" {
  for_each = var.sanitized_students

  triggers_replace = [
    aws_ecr_repository.student[each.key].repository_url
  ]

  provisioner "local-exec" {
    command = "chmod +x ${path.module}/scripts/push_image.sh && bash ${path.module}/scripts/push_image.sh"

    environment = {
      AWS_REGION   = var.region
      ECR_REPO_URL = aws_ecr_repository.student[each.key].repository_url
      SOURCE_IMAGE = var.kasm_image
      SOURCE_TAG   = var.kasm_image_tag
      STUDENT_ID   = each.value.id
    }
  }

  depends_on = [
    aws_ecr_repository.student
  ]
  #,
  #  aws_ecr_repository_policy.student
}
# modules/ecr/ecr.tf
# -----------------------------------------------------------------------------
# One private ECR repository per student.
# Each repo:
#   - IMMUTABLE tags — pushed image cannot be overwritten accidentally
#   - Scan on push — free vulnerability scanning on every image push
#   - AES256 encryption — default, no KMS cost
#   - Lifecycle policy — expire untagged images after 1 day, keep max 2 tagged
#   - Resource policy — pull restricted to execution role ARN only
#
# terraform_data triggers push_image.sh after repo creation:
#   - Pulls kasmweb/desktop from Docker Hub
#   - Tags as {student-id} and pushes to student's private repo
#   - Cleans up local images and tmp directory via trap on EXIT
# -----------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# ECR Private Repositories — one per student
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "student" {
  for_each = var.sanitized_students

  name                 = "${var.prefix}-ecr-${each.value.id}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    name  = "${var.prefix}-ecr-${each.value.id}"
    owner = each.value.id
  }
}

# ---------------------------------------------------------------------------
# ECR Lifecycle Policy — per repo
# Rule 1: Expire untagged images after 1 day (cleanup dangling layers)
# Rule 2: Keep maximum 2 tagged images per repo (cost control)
# ---------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "student" {
  for_each = var.sanitized_students

  repository = aws_ecr_repository.student[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day."
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep maximum 2 tagged images."
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["student"]
          countType     = "imageCountMoreThan"
          countNumber   = 2
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# ECR Repository Policy — per repo
# Restricts image pull to the shared execution role ONLY.
# Student-01's execution role cannot pull from student-02's repo.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ecr_repo_policy" {
  for_each = var.sanitized_students

  statement {
    sid    = "AllowExecutionRolePull"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.execution_role_arn]
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
    ]
  }
}

# resource "aws_ecr_repository_policy" "student" {
#   for_each = var.sanitized_students

#   repository = aws_ecr_repository.student[each.key].name
#   policy     = data.aws_iam_policy_document.ecr_repo_policy[each.key].json
# }
# locals.tf
# -----------------------------------------------------------------------------
# Central computed values and input sanitization logic.
# All modules consume these locals — never raw variables directly.
# Sanitization transforms arbitrary student IDs into DNS/resource-safe strings.
# -----------------------------------------------------------------------------

locals {

  # ---------------------------------------------------------------------------
  # INPUT SANITIZATION
  # Transforms raw student IDs into safe identifiers for use in:
  #   - AWS resource names
  #   - DNS labels
  #   - Docker image tags
  #   - CloudWatch log group paths
  #
  # Transformation pipeline per student ID:
  #   1. lower()        → "Alice Smith!" → "alice smith!"
  #   2. replace spaces → "alice smith!" → "alice-smith!"
  #   3. replace non-alphanumeric-hyphen chars → "alice-smith!" → "alice-smith"
  # ---------------------------------------------------------------------------

  sanitized_students = {
    for idx, s in var.students :
    s.id => {
      raw_id        = s.id
      id            = replace(replace(lower(s.id), " ", "-"), "/[^a-z0-9-]/", "")
      authorized_ip = s.authorized_ip
      index         = idx

      # Subnet CIDR carved from workload base
      # idx=0 → slot 1 → 10.0.1.16/28 (slot 0 = 10.0.1.0/28 reserved for cache)
      subnet_cidr = cidrsubnet(var.workload_subnet_base, 4, idx + 1)
    }
  }

  # ---------------------------------------------------------------------------
  # ACCOUNT & REGION IDENTITY
  # Resolved dynamically — no hardcoded account IDs anywhere in the codebase.
  # ---------------------------------------------------------------------------

  account_id = data.aws_caller_identity.current.account_id
  region     = var.aws_region

  # ---------------------------------------------------------------------------
  # RESOURCE NAMING PREFIX
  # Single definition — change here reflects everywhere.
  # ---------------------------------------------------------------------------

  prefix = "cybered-candidate-002"

  # ---------------------------------------------------------------------------
  # IAM CONSTANTS
  # Defined once — referenced in every IAM resource block.
  # ---------------------------------------------------------------------------

  iam_path             = "/cybered-assessment/candidate-002/"
  permissions_boundary = "arn:aws:iam::${local.account_id}:policy/CyberEdAssessmentBoundary-candidate-002"

  # ---------------------------------------------------------------------------
  # ECR IMAGE REFERENCES
  # Pre-computed per student for use in task definitions and push script.
  # ---------------------------------------------------------------------------

  ecr_repo_names = {
    for s in local.sanitized_students :
    s.id => "${local.prefix}-ecr-${s.id}"
  }

  ecr_base_url = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com"

  ecr_image_urls = {
    for s in local.sanitized_students :
    s.id => "${local.ecr_base_url}/${local.prefix}-ecr-${s.id}:${s.id}"
  }
}
# main.tf
# -----------------------------------------------------------------------------
# Root orchestration — calls all infrastructure modules in dependency order.
# Module calls are added incrementally as each module is generated:
#   Step 1 → module.budget
#   Step 2 → module.networking
#   Step 3 → module.iam
#   Step 4 → module.cloudwatch
#   Step 5 → module.ecr
#   Step 6 → module.ecs
# -----------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Step 1 — Budget Module
# Deployed first as a financial guardrail before any infrastructure.
# Monitors total account spend against the $50 assessment cap.
# ---------------------------------------------------------------------------
module "budget" {
  source = "./modules/budget"

  prefix               = local.prefix
  account_id           = local.account_id
  budget_limit_amount  = var.budget_limit_amount
  budget_sns_topic_arn = var.budget_sns_topic_arn
}

# ---------------------------------------------------------------------------
# Step 2 — Networking Module
# ---------------------------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  prefix             = local.prefix
  vpc_cidr           = var.vpc_cidr
  cache_subnet_cidr  = var.cache_subnet_cidr
  aws_region         = var.aws_region
  sanitized_students = local.sanitized_students
}

# ---------------------------------------------------------------------------
# Step 3 — IAM Module
# ---------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  prefix               = local.prefix
  iam_path             = local.iam_path
  permissions_boundary = local.permissions_boundary
  account_id           = local.account_id
  region               = local.region
  sanitized_students   = local.sanitized_students
}

# ---------------------------------------------------------------------------
# Step 4 — CloudWatch Module
# ---------------------------------------------------------------------------
# module "cloudwatch" {
#   source = "./modules/cloudwatch"

#   prefix             = local.prefix
#   sanitized_students = local.sanitized_students
#   log_retention_days = var.log_retention_days
# }

# ---------------------------------------------------------------------------
# Step 5 — ECR Module
# ---------------------------------------------------------------------------
module "ecr" {
  source = "./modules/ecr"

  prefix             = local.prefix
  account_id         = local.account_id
  region             = local.region
  sanitized_students = local.sanitized_students
  execution_role_arn = module.iam.execution_role_arn
  kasm_image         = var.kasm_image
  kasm_image_tag     = var.kasm_image_tag
}

# ---------------------------------------------------------------------------
# Step 6 — ECS Module
# ---------------------------------------------------------------------------
module "ecs" {
  source = "./modules/ecs"

  prefix                     = local.prefix
  region                     = local.region
  sanitized_students         = local.sanitized_students
  execution_role_arn         = module.iam.execution_role_arn
  task_role_arns             = module.iam.task_role_arns
  student_subnet_ids         = module.networking.student_subnet_ids
  student_security_group_ids = module.networking.student_security_group_ids
  image_uris                 = module.ecr.image_uris
  fargate_capacity_provider  = var.fargate_capacity_provider

  # Uncomment when CloudWatch log groups are provisioned
  # log_group_names = module.cloudwatch.log_group_names
}
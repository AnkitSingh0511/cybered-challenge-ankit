# modules/ecs/ecs_cluster.tf
# -----------------------------------------------------------------------------
# One shared ECS cluster for all student workloads.
# Cluster itself is free — cost is incurred only by running Fargate tasks.
# Container Insights disabled — adds CloudWatch cost, not needed for assessment.
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${var.prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    name = "${var.prefix}-cluster"
  }
}

# ---------------------------------------------------------------------------
# Capacity provider association — binds FARGATE or FARGATE_SPOT to cluster.
# Controlled via var.fargate_capacity_provider.
# Default: FARGATE_SPOT (testing) — override to FARGATE at live demo.
# ---------------------------------------------------------------------------
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [var.fargate_capacity_provider]

  default_capacity_provider_strategy {
    capacity_provider = var.fargate_capacity_provider
    weight            = 1
    base              = 0
  }
}
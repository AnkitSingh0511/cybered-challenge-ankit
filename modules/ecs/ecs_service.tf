# modules/ecs/ecs_service.tf
# -----------------------------------------------------------------------------
# One ECS Service per student — dynamic via for_each.
# Each service:
#   - Runs exactly 1 task (one desktop per student)
#   - Places task in that student's dedicated subnet
#   - Attaches that student's dedicated security group
#   - Assigns a public IP (required — no NAT Gateway available)
#   - Uses FARGATE or FARGATE_SPOT per var.fargate_capacity_provider
# -----------------------------------------------------------------------------

resource "aws_ecs_service" "student" {
  for_each = var.sanitized_students

  name            = "${var.prefix}-svc-${each.value.id}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.student[each.key].arn
  desired_count   = 1

  # Health check grace period — gives KasmWeb time to boot before
  # ECS starts evaluating service-level health.
  #health_check_grace_period_seconds = 300

  capacity_provider_strategy {
    capacity_provider = var.fargate_capacity_provider
    weight            = 1
    base              = 0
  }

  network_configuration {
    subnets          = [var.student_subnet_ids[each.value.id]]
    security_groups  = [var.student_security_group_ids[each.value.id]]
    assign_public_ip = true
  }

  # Ignore task definition changes after initial deployment.
  # Prevents Terraform from forcing task restarts on every plan
  # when ECS updates the active task definition revision.
  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = {
    name  = "${var.prefix}-svc-${each.value.id}"
    owner = each.value.id
  }

  depends_on = [
    aws_ecs_cluster_capacity_providers.main,
    aws_ecs_task_definition.student
  ]
}
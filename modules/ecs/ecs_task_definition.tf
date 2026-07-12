# modules/ecs/ecs_task_definition.tf
# -----------------------------------------------------------------------------
# One task definition per student — dynamic via for_each.
# Each task definition:
#   - References that student's private ECR image URI
#   - Uses the shared execution role (ECR pull, log write)
#   - Uses that student's dedicated task role (app-level permissions)
#   - Exposes port 6901 (KasmWeb HTTPS desktop UI)
#   - CACHE_HOST and CACHE_PORT placeholders — updated in cache MVP phase
#
# Logging:
#   - awslogs driver config is commented out pending CloudWatch log group
#     provisioning. Uncomment both the log driver block and the
#     log_group_names variable when log groups are available.
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "student" {
  for_each = var.sanitized_students

  family                   = "${var.prefix}-task-${each.value.id}"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arns[each.value.id]

  container_definitions = jsonencode([
    {
      name      = "${var.prefix}-container-${each.value.id}"
      image     = var.image_uris[each.value.id]
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
          name          = "http"
        }
      ]

      environment = [
        {
          name  = "CACHE_HOST"
          value = "placeholder"
        },
        {
          name  = "CACHE_PORT"
          value = "6379"
        },
        {
          name  = "VNC_PW"
          value = "password"
        },
        {
          name  = "VNC_USER"
          value = "kasm_user"
        }
      ]

      # ------------------------------------------------------------------
      # Logging — commented out pending CloudWatch log group provisioning.
      # Once log groups exist, uncomment the logConfiguration block below
      # and the log_group_names variable in variables.tf.
      # Also uncomment the log_group_names input in the module call
      # inside root main.tf.
      # ------------------------------------------------------------------
      # logConfiguration = {
      #   logDriver = "awslogs"
      #   options = {
      #     "awslogs-group"         = var.log_group_names[each.value.id]
      #     "awslogs-region"        = var.region
      #     "awslogs-stream-prefix" = each.value.id
      #   }
      # }

    #   healthCheck = {
    #     command     = ["CMD-SHELL", "curl -k https://localhost:6901/ || exit 1"]
    #     interval    = 30
    #     timeout     = 5
    #     retries     = 3
    #     startPeriod = 300
    #   }
    }
  ])

  tags = {
    name  = "${var.prefix}-task-${each.value.id}"
    owner = each.value.id
  }
}
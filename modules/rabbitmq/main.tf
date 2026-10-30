data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_role" "lab_role" {
  name = var.lab_role_name
}

locals {
  image_url = var.ecr_image_url != "" ? var.ecr_image_url : "rabbitmq:3.13-management-alpine"
}

# ----------------------------------------------------------------------------
# 1. Security Group para o RabbitMQ no ECS Fargate
# ----------------------------------------------------------------------------
resource "aws_security_group" "rabbitmq" {
  name        = "${var.project_name}-sg-rabbitmq-${var.environment}"
  description = "Security Group do servico RabbitMQ ECS"
  vpc_id      = var.vpc_id

  # Porta AMQP (5672) liberada para as instancias do backend
  ingress {
    description     = "AMQP da camada backend"
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [var.backend_sg_id]
  }

  # Porta Management Dashboard (15672) liberada para a camada backend/interna
  ingress {
    description     = "Management UI RabbitMQ"
    from_port       = 15672
    to_port         = 15672
    protocol        = "tcp"
    security_groups = [var.backend_sg_id]
  }

  egress {
    description = "Saida irrestrita para downloads e comunicacao"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg-rabbitmq-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ----------------------------------------------------------------------------
# 2. Namespace Privado de DNS para Service Discovery interno na VPC
# ----------------------------------------------------------------------------
resource "aws_service_discovery_private_dns_namespace" "lumina" {
  name        = "lumina.local"
  description = "Namespace privado para resolucao de servicos internos ECS"
  vpc         = var.vpc_id

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_service_discovery_service" "rabbitmq" {
  name = "rabbitmq"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.lumina.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ----------------------------------------------------------------------------
# 3. ECS Cluster dedicado ao RabbitMQ
# ----------------------------------------------------------------------------
resource "aws_ecs_cluster" "rabbitmq" {
  name = "${var.project_name}-cluster-rabbitmq-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ----------------------------------------------------------------------------
# 4. CloudWatch Logs
# ----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "rabbitmq" {
  name              = "/ecs/${var.project_name}-rabbitmq-${var.environment}"
  retention_in_days = 3

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ----------------------------------------------------------------------------
# 5. Task Definition Fargate com LabRole
# ----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "rabbitmq" {
  family                   = "${var.project_name}-rabbitmq-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "rabbitmq"
      image     = local.image_url
      essential = true

      portMappings = [
        {
          containerPort = 5672
          hostPort      = 5672
          protocol      = "tcp"
        },
        {
          containerPort = 15672
          hostPort      = 15672
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "RABBITMQ_DEFAULT_USER"
          value = var.rabbitmq_user
        },
        {
          name  = "RABBITMQ_DEFAULT_PASS"
          value = var.rabbitmq_password
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.rabbitmq.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "rabbitmq"
        }
      }
    }
  ])

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ----------------------------------------------------------------------------
# 6. ECS Service Fargate
# ----------------------------------------------------------------------------
resource "aws_ecs_service" "rabbitmq" {
  name            = "${var.project_name}-svc-rabbitmq-${var.environment}"
  cluster         = aws_ecs_cluster.rabbitmq.id
  task_definition = aws_ecs_task_definition.rabbitmq.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.rabbitmq.id]
    assign_public_ip = var.is_dev
  }

  service_registries {
    registry_arn = aws_service_discovery_service.rabbitmq.arn
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

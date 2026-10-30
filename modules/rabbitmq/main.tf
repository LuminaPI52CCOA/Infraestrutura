data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_role" "lab_role" {
  name = var.lab_role_name
}

data "aws_vpc" "selected" {
  id = var.vpc_id
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

  # Porta AMQP (5672) liberada para a VPC interna (NLB health checks e backend)
  ingress {
    description = "AMQP interno via VPC e Backend"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  # Porta Management Dashboard (15672) liberada para a VPC interna
  ingress {
    description = "Management UI RabbitMQ"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
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
# 2. Network Load Balancer (NLB) Interno para o RabbitMQ
# Substitui o Route53 / ServiceDiscovery bloqueado pelas SCPs da AWS Academy
# ----------------------------------------------------------------------------
resource "aws_lb" "rabbitmq" {
  name               = "${var.project_name}-nlb-mq-${var.environment}"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  tags = {
    Name        = "${var.project_name}-nlb-rabbitmq-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "rabbitmq" {
  name        = "${var.project_name}-tg-mq-${var.environment}"
  port        = 5672
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    port                = "5672"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = {
    Name        = "${var.project_name}-tg-rabbitmq-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_lb_listener" "rabbitmq" {
  load_balancer_arn = aws_lb.rabbitmq.arn
  port              = 5672
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rabbitmq.arn
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
# 6. ECS Service Fargate integrado ao NLB
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

  load_balancer {
    target_group_arn = aws_lb_target_group.rabbitmq.arn
    container_name   = "rabbitmq"
    container_port   = 5672
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

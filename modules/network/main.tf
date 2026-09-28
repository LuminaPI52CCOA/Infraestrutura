# ==============================================================================
# VPC e Internet Gateway
# ==============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw-${var.environment}"
    Environment = var.environment
  }
}

# ==============================================================================
# Sub-redes Publicas (Minimo 2 zonas para o ALB Publico)
# ==============================================================================

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}-${var.environment}"
    Type        = "Public"
    Environment = var.environment
    AZ          = var.availability_zones[count.index % length(var.availability_zones)]
  }
}

# ==============================================================================
# Sub-redes Privadas (Camada de Aplicacao / Backend)
# ==============================================================================

resource "aws_subnet" "private_app" {
  count             = length(var.private_app_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]

  tags = {
    Name        = "${var.project_name}-private-app-subnet-${count.index + 1}-${var.environment}"
    Type        = "Private-App"
    Environment = var.environment
    AZ          = var.availability_zones[count.index % length(var.availability_zones)]
  }
}

# ==============================================================================
# Sub-redes Privadas (Camada de Dados / Database)
# ==============================================================================

resource "aws_subnet" "private_db" {
  count             = length(var.private_db_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]

  tags = {
    Name        = "${var.project_name}-private-db-subnet-${count.index + 1}-${var.environment}"
    Type        = "Private-DB"
    Environment = var.environment
    AZ          = var.availability_zones[count.index % length(var.availability_zones)]
  }
}

# ==============================================================================
# Tabelas de Roteamento Publicas
# ==============================================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.project_name}-rt-public-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ==============================================================================
# NAT Gateway e Elastic IP (Modo Prod)
# ==============================================================================

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.project_name}-nat-gw-${var.environment}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.igw]
}

# ==============================================================================
# Tabelas de Roteamento Privadas
# ==============================================================================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.nat[0].id
    }
  }

  tags = {
    Name        = "${var.project_name}-rt-private-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_app" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_db" {
  count          = length(aws_subnet.private_db)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private.id
}

# ==============================================================================
# VPC Endpoint S3 (Conexão interna e direta)
# ==============================================================================

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.public.id,
    aws_route_table.private.id
  ]

  tags = {
    Name        = "${var.project_name}-vpce-s3-${var.environment}"
    Environment = var.environment
  }
}

# ==============================================================================
# Application Load Balancer Publico (Internet-Facing)
# ==============================================================================

resource "aws_lb" "public" {
  name               = "${var.project_name}-alb-pub-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_public.id]
  subnets            = [for s in aws_subnet.public : s.id]

  tags = {
    Name        = "${var.project_name}-alb-public-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-tg-front-${var.environment}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-tg-frontend-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# ==============================================================================
# Application Load Balancer Interno (Modo Prod)
# ==============================================================================

resource "aws_lb" "internal" {
  count              = var.enable_internal_alb ? 1 : 0
  name               = "${var.project_name}-alb-int-${var.environment}"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_internal[0].id]
  subnets            = [for s in aws_subnet.private_app : s.id]

  tags = {
    Name        = "${var.project_name}-alb-internal-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "backend" {
  count       = var.enable_internal_alb ? 1 : 0
  name        = "${var.project_name}-tg-back-${var.environment}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/actuator/health"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-tg-backend-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "internal_http" {
  count             = var.enable_internal_alb ? 1 : 0
  load_balancer_arn = aws_lb.internal[0].arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend[0].arn
  }
}

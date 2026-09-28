# ==============================================================================
# Security Groups com Principio do Menor Privilegio
# ==============================================================================

# 1. ALB Publico (Internet-Facing)
resource "aws_security_group" "alb_public" {
  name        = "${var.project_name}-sg-alb-pub-${var.environment}"
  description = "Trafego HTTP/HTTPS publico vindo da Internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP da Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS da Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Saida irrestrita"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg-alb-public-${var.environment}"
    Environment = var.environment
  }
}

# 2. Bastion Host (Jump Host)
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-sg-bastion-${var.environment}"
  description = "Acesso SSH administrativo seguro"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH Administrativo"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ssh_cidr]
  }

  egress {
    description = "Saida irrestrita para VPC e Internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg-bastion-${var.environment}"
    Environment = var.environment
  }
}

# 3. Frontend (NGINX + React SPA)
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-sg-front-${var.environment}"
  description = "Acesso HTTP apenas do ALB Publico e SSH do Bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP a partir do ALB Publico"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_public.id]
  }

  ingress {
    description     = "SSH a partir do Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Saida para VPC e servicos externos"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg-frontend-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_security_group_rule" "frontend_ssh_direct_dev" {
  count             = var.is_dev ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.admin_ssh_cidr]
  security_group_id = aws_security_group.frontend.id
  description       = "SSH direto para desenvolvedores em dev"
}

# 4. ALB Interno (Modo Prod)
resource "aws_security_group" "alb_internal" {
  count       = var.enable_internal_alb ? 1 : 0
  name        = "${var.project_name}-sg-alb-int-${var.environment}"
  description = "Trafego interno vindo exclusivamente do Frontend"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP a partir do Frontend"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  ingress {
    description     = "API 8080 a partir do Frontend"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    description = "Saida para os servidores backend"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg-alb-internal-${var.environment}"
    Environment = var.environment
  }
}

# 5. Backend (Spring Boot / Java)
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-sg-back-${var.environment}"
  description = "Trafego para a API Spring Boot"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH a partir do Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Saida para banco de dados e servicos"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg-backend-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_security_group_rule" "backend_from_alb_internal" {
  count                    = var.enable_internal_alb ? 1 : 0
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_internal[0].id
  security_group_id        = aws_security_group.backend.id
  description              = "API 8080 a partir do ALB Interno"
}

resource "aws_security_group_rule" "backend_from_frontend_dev" {
  count                    = var.enable_internal_alb ? 0 : 1
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.frontend.id
  security_group_id        = aws_security_group.backend.id
  description              = "API 8080 direta do Frontend (modo dev)"
}

resource "aws_security_group_rule" "backend_from_alb_public_dev" {
  count                    = var.enable_internal_alb ? 0 : 1
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_public.id
  security_group_id        = aws_security_group.backend.id
  description              = "API 8080 a partir do ALB Publico (modo dev)"
}

resource "aws_security_group_rule" "backend_ssh_direct_dev" {
  count             = var.is_dev ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.admin_ssh_cidr]
  security_group_id = aws_security_group.backend.id
  description       = "SSH direto para desenvolvedores em dev"
}

# 6. Database (MySQL Server)
resource "aws_security_group" "database" {
  name        = "${var.project_name}-sg-db-${var.environment}"
  description = "Acesso restrito ao MySQL na porta 3306"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL a partir do Backend"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  ingress {
    description     = "MySQL a partir do Bastion"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description = "Replicacao entre nos de banco"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description     = "SSH a partir do Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Saida para atualizacoes e storage"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg-database-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_security_group_rule" "database_ssh_direct_dev" {
  count             = var.is_dev ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.admin_ssh_cidr]
  security_group_id = aws_security_group.database.id
  description       = "SSH direto para manutencao do DB em dev"
}

# 7. EFS Storage Compartilhado (Modo Prod)
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-sg-efs-${var.environment}"
  description = "Acesso NFS ao EFS compartilhado"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS a partir do Banco de Dados"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.database.id]
  }

  ingress {
    description     = "NFS a partir do Backend"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    description = "Saida para a VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg-efs-${var.environment}"
    Environment = var.environment
  }
}

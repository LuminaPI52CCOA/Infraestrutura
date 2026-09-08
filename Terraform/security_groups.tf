# ==============================================================================
# Grupos de Seguranca (Security Groups) com Principio do Menor Privilegio
# ==============================================================================

# 1. Security Group para o Application Load Balancer Publico (Internet-Facing)
resource "aws_security_group" "alb_public" {
  name        = "${var.project_name}-sg-alb-public"
  description = "Permite trafego HTTP/HTTPS publico vindo da Internet"
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
    Name = "${var.project_name}-sg-alb-public"
  }
}

# 2. Security Group para o Bastion Host (Jump Host)
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-sg-bastion"
  description = "Permite acesso SSH administrativo"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH Administrativo"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ssh_cidr]
  }

  egress {
    description = "Saida para a VPC e Internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-bastion"
  }
}

# 3. Security Group para o Frontend (React - Sub-redes Publicas)
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-sg-frontend"
  description = "Permite conexoes apenas a partir do ALB Publico e Bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP a partir do ALB Publico"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_public.id]
  }

  ingress {
    description     = "Porta Node/React 3000 do ALB Publico"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_public.id]
  }

  ingress {
    description     = "SSH a partir do Bastion Host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Saida para comunicacao com a rede interna e endpoints"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-frontend"
  }
}

# 4. Security Group para o Application Load Balancer Interno / Privado
resource "aws_security_group" "alb_internal" {
  name        = "${var.project_name}-sg-alb-internal"
  description = "Permite trafego interno vindo exclusivamente do Frontend"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Trafego HTTP do Frontend"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  ingress {
    description     = "Trafego API (8080) do Frontend"
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
    Name = "${var.project_name}-sg-alb-internal"
  }
}

# 5. Security Group para o Backend (Spring Boot / Java - Sub-redes Privadas 1 e 2)
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-sg-backend"
  description = "Permite trafego do ALB Interno e administracao via Bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Trafego HTTP/API a partir do ALB Interno"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_internal.id]
  }

  ingress {
    description     = "SSH a partir do Bastion Host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Saida para banco de dados, storage e servicos AWS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-backend"
  }
}

# 6. Security Group para o Banco de Dados (MySQL - Sub-redes Privadas 3 e 4)
resource "aws_security_group" "database" {
  name        = "${var.project_name}-sg-database"
  description = "Permite conexoes MySQL a partir do Backend e Bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL a partir da camada Backend"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  ingress {
    description     = "MySQL administrativo a partir do Bastion"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description = "Replicacao MySQL entre os nos de banco"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Saida para EFS e VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-database"
  }
}

# 7. Security Group para o Amazon EFS (Elastic File System)
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-sg-efs"
  description = "Permite conexoes NFS a partir do Banco de Dados e Backend"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS a partir da camada de Banco de Dados"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.database.id]
  }

  ingress {
    description     = "NFS a partir da camada Backend"
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
    Name = "${var.project_name}-sg-efs"
  }
}

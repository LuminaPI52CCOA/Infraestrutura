resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-sub-rede-publica-1"
    Type = "Public"
    AZ   = var.availability_zones[0]
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-sub-rede-publica-2"
    Type = "Public"
    AZ   = var.availability_zones[1]
  }
}

# ==============================================================================
# Sub-redes Privadas (Camada de Aplicação / Backend)
# ==============================================================================

# Sub-rede privada 1 (Zona de disponibilidade A)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "${var.project_name}-sub-rede-privada-1"
    Type = "Private-App"
    AZ   = var.availability_zones[0]
  }
}

# Sub-rede privada 2 (Zona de disponibilidade B)
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "${var.project_name}-sub-rede-privada-2"
    Type = "Private-App"
    AZ   = var.availability_zones[1]
  }
}

# ==============================================================================
# Sub-redes Privadas (Camada de Banco de Dados / Storage)
# ==============================================================================

# Sub-rede privada 3 (Zona de disponibilidade A)
resource "aws_subnet" "private_3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_3_cidr
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "${var.project_name}-sub-rede-privada-3"
    Type = "Private-DB"
    AZ   = var.availability_zones[0]
  }
}

# Sub-rede privada 4 (Zona de disponibilidade B)
resource "aws_subnet" "private_4" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_4_cidr
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "${var.project_name}-sub-rede-privada-4"
    Type = "Private-DB"
    AZ   = var.availability_zones[1]
  }
}

# ==============================================================================
# Tabelas de Roteamento (Route Tables)
# ==============================================================================

# Tabela de Roteamento Pública (com saída para o Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-rt-publica"
  }
}

# Associação das Sub-redes Públicas à Tabela de Roteamento Pública
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ==============================================================================
# NAT Gateway (Permite que o Backend nas sub-redes privadas baixe pacotes e clone o Git)
# ==============================================================================

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Tabela de Roteamento Privada
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
    Name = "${var.project_name}-rt-privada"
  }
}

# Associação das Sub-redes Privadas (1, 2, 3 e 4) à Tabela Privada
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_3" {
  subnet_id      = aws_subnet.private_3.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_4" {
  subnet_id      = aws_subnet.private_4.id
  route_table_id = aws_route_table.private.id
}

# ==============================================================================
# VPC Endpoints (Conexão Segura e Direta aos Serviços AWS)
# ==============================================================================

# VPC Endpoint para o Amazon S3 (Gateway Endpoint)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.public.id,
    aws_route_table.private.id
  ]

  tags = {
    Name = "${var.project_name}-vpce-s3"
  }
}

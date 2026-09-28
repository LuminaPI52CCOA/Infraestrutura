data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical oficial

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_instance_profile" "lab_profile" {
  name = var.lab_instance_profile_name
}

resource "aws_instance" "database" {
  count                  = var.instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name
  key_name               = var.key_name != "" ? var.key_name : null

  associate_public_ip_address = var.associate_public_ip_address

  user_data = <<-EOF
              #!/bin/bash
              set -e
              export DEBIAN_FRONTEND=noninteractive

              exec > >(tee -a /var/log/database-provision.log) 2>&1

              # 1. Instalacao do MySQL Server Oficial
              apt-get update -y
              apt-get install -y mysql-server git

              # 2. Configurar MySQL para escutar em todas as interfaces da VPC
              sed -i 's/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf || true
              systemctl restart mysql
              systemctl enable mysql

              # 3. Clone do repositorio de Banco de Dados e Carga do lumina.sql
              mkdir -p /opt/lumina-database
              git clone --depth 1 -b ${var.db_repo_branch} ${var.db_repo_url} /opt/lumina-database || git clone --depth 1 ${var.db_repo_url} /opt/lumina-database

              # 4. Executar o DDL oficial e massa de dados mockada (schema Lumina e john@doe.com)
              mysql -u root < /opt/lumina-database/lumina.sql

              # 5. Criar usuario da aplicacao com privilegios na VPC
              mysql -u root << EOSQL
              CREATE USER IF NOT EXISTS '${var.db_user}'@'%' IDENTIFIED BY '${var.db_password}';
              GRANT ALL PRIVILEGES ON Lumina.* TO '${var.db_user}'@'%';
              FLUSH PRIVILEGES;
              EOSQL
              EOF

  tags = {
    Name        = "${var.project_name}-database-${count.index + 1}-${var.environment}"
    Tier        = "Database"
    Environment = var.environment
  }
}

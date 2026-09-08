# ==============================================================================
# Instâncias Computacionais (EC2) com Provisionamento Automatizado dos Repositórios
# Sistema Operacional: Ubuntu Server 22.04 LTS
# ==============================================================================

# Busca da AMI mais recente do Ubuntu Server 22.04 LTS
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

# ------------------------------------------------------------------------------
# 1. Bastion Host (Sub-rede Pública 2 - Zona de Disponibilidade B)
# ------------------------------------------------------------------------------
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_bastion
  subnet_id              = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name
  key_name               = var.ssh_key_name != "" ? var.ssh_key_name : null

  user_data = <<-EOF
              #!/bin/bash
              set -e
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get install -y nginx

              # Remover site padrão do NGINX no Ubuntu
              rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default

              mkdir -p /var/www/html
              cat << 'HTML' > /var/www/html/index.html
              <!DOCTYPE html>
              <html>
              <head><title>Bastion Host</title><style>body{font-family:sans-serif;text-align:center;padding:50px;background:#1e293b;color:#f8fafc;}h1{color:#38bdf8;}</style></head>
              <body>
                <h1>🛡️ Bastion Host / Jump Server (Ubuntu)</h1>
                <p>Status: Operacional | NGINX Configurado</p>
                <p>Zona: ${var.availability_zones[1]}</p>
              </body>
              </html>
              HTML

              cat << 'CONF' > /etc/nginx/conf.d/bastion.conf
              server {
                  listen 80 default_server;
                  server_name _;
                  root /var/www/html;
                  index index.html;
              }
              CONF

              systemctl enable nginx
              systemctl restart nginx
              EOF

  tags = {
    Name = "${var.project_name}-public-bastion-host"
    Role = "Bastion"
    Type = "Public"
  }
}

# ------------------------------------------------------------------------------
# 2. Camada Frontend (React - Repositório Lumina Front-End / main)
# ------------------------------------------------------------------------------

# Frontend na Zona de Disponibilidade A (Sub-rede pública 1)
resource "aws_instance" "frontend_a" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_frontend
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name
  key_name               = var.ssh_key_name != "" ? var.ssh_key_name : null

  user_data = <<-EOF
              #!/bin/bash
              set -e
              export DEBIAN_FRONTEND=noninteractive

              # Log de todo o processo de inicializacao
              exec > >(tee -a /var/log/frontend-provision.log) 2>&1

              # Criar swapfile de 2GB para evitar OOM (Out Of Memory) no t3.micro durante build
              if ! swapon --show | grep -q "/swapfile"; then
                fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
              fi

              # Atualizacao de pacotes e instalacao de dependencias essenciais
              apt-get update -y
              apt-get install -y curl ca-certificates gnupg git nginx

              # Configurar e iniciar NGINX com pagina temporaria (para o ALB Health Check passar de imediato)
              rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/lumina-frontend.conf
              mkdir -p /var/www/html
              cat << 'HTML' > /var/www/html/index.html
              <!DOCTYPE html>
              <html>
              <head><meta charset="utf-8"><title>Lumina - Inicializando</title></head>
              <body style="font-family:sans-serif;text-align:center;padding:50px;background:#0f172a;color:#f8fafc;">
                <h1>⚡ Lumina - Inicializando Frontend</h1>
                <p>O bundle React / Vite está sendo construído e configurado no NGINX. Aguarde alguns instantes e atualize a página.</p>
              </body>
              </html>
              HTML

              cat << 'CONF' > /etc/nginx/sites-available/lumina-frontend.conf
              server {
                  listen 80 default_server;
                  server_name _;
                  root /var/www/html;
                  index index.html;

                  # Roteamento SPA React
                  location / {
                      try_files $uri $uri/ /index.html;
                  }

                  # Proxy reverso para as chamadas de API direcionadas ao ALB Interno
                  location ~ ^/(usuarios|clientes|consultas|convenios|anamnese|perfis|swagger-ui|v3|actuator|api) {
                      proxy_pass http://${aws_lb.internal.dns_name}:8080;
                      proxy_http_version 1.1;
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;
                      proxy_connect_timeout 60s;
                      proxy_read_timeout 60s;
                  }
              }
              CONF

              ln -sf /etc/nginx/sites-available/lumina-frontend.conf /etc/nginx/sites-enabled/lumina-frontend.conf
              nginx -t
              systemctl enable nginx
              systemctl restart nginx

              # Instalar Node.js 20 LTS oficial (necessario para Vite 6 / React 19)
              curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
              apt-get install -y nodejs

              # Clonar repositório Front-End da branch main
              rm -rf /opt/lumina-frontend
              mkdir -p /opt/lumina-frontend
              git clone --depth 1 -b ${var.frontend_repo_branch} ${var.frontend_repo_url} /opt/lumina-frontend

              # Ajustar API_BASE_URL para caminhos relativos (utilizando proxy reverso NGINX)
              cd /opt/lumina-frontend
              sed -i "s|export const API_BASE_URL = .*;|export const API_BASE_URL = '';|g" src/api/config.js 2>/dev/null || true

              # Instalação das dependências e build estático com Vite
              npm install --legacy-peer-deps
              npm run build

              # Copiar bundle final para o diretório web do NGINX
              rm -rf /var/www/html/*
              cp -r dist/* /var/www/html/
              chown -R www-data:www-data /var/www/html
              chmod -R 755 /var/www/html

              # Recarregar NGINX com a aplicacao React construida
              systemctl reload nginx
              EOF

  tags = {
    Name = "${var.project_name}-public-frontend-react-az-a"
    Tier = "Frontend"
    Type = "Public"
    AZ   = var.availability_zones[0]
  }
}

# Frontend na Zona de Disponibilidade B (Sub-rede pública 2)
resource "aws_instance" "frontend_b" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_frontend
  subnet_id              = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name
  key_name               = var.ssh_key_name != "" ? var.ssh_key_name : null

  user_data = <<-EOF
              #!/bin/bash
              set -e
              export DEBIAN_FRONTEND=noninteractive

              # Log de todo o processo de inicializacao
              exec > >(tee -a /var/log/frontend-provision.log) 2>&1

              # Criar swapfile de 2GB para evitar OOM (Out Of Memory) no t3.micro durante build
              if ! swapon --show | grep -q "/swapfile"; then
                fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
              fi

              # Atualizacao de pacotes e instalacao de dependencias essenciais
              apt-get update -y
              apt-get install -y curl ca-certificates gnupg git nginx

              # Configurar e iniciar NGINX com pagina temporaria (para o ALB Health Check passar de imediato)
              rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/lumina-frontend.conf
              mkdir -p /var/www/html
              cat << 'HTML' > /var/www/html/index.html
              <!DOCTYPE html>
              <html>
              <head><meta charset="utf-8"><title>Lumina - Inicializando</title></head>
              <body style="font-family:sans-serif;text-align:center;padding:50px;background:#0f172a;color:#f8fafc;">
                <h1>⚡ Lumina - Inicializando Frontend</h1>
                <p>O bundle React / Vite está sendo construído e configurado no NGINX. Aguarde alguns instantes e atualize a página.</p>
              </body>
              </html>
              HTML

              cat << 'CONF' > /etc/nginx/sites-available/lumina-frontend.conf
              server {
                  listen 80 default_server;
                  server_name _;
                  root /var/www/html;
                  index index.html;

                  # Roteamento SPA React
                  location / {
                      try_files $uri $uri/ /index.html;
                  }

                  # Proxy reverso para as chamadas de API direcionadas ao ALB Interno
                  location ~ ^/(usuarios|clientes|consultas|convenios|anamnese|perfis|swagger-ui|v3|actuator|api) {
                      proxy_pass http://${aws_lb.internal.dns_name}:8080;
                      proxy_http_version 1.1;
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;
                      proxy_connect_timeout 60s;
                      proxy_read_timeout 60s;
                  }
              }
              CONF

              ln -sf /etc/nginx/sites-available/lumina-frontend.conf /etc/nginx/sites-enabled/lumina-frontend.conf
              nginx -t
              systemctl enable nginx
              systemctl restart nginx

              # Instalar Node.js 20 LTS oficial (necessario para Vite 6 / React 19)
              curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
              apt-get install -y nodejs

              # Clonar repositório Front-End da branch main
              rm -rf /opt/lumina-frontend
              mkdir -p /opt/lumina-frontend
              git clone --depth 1 -b ${var.frontend_repo_branch} ${var.frontend_repo_url} /opt/lumina-frontend

              # Ajustar API_BASE_URL para caminhos relativos (utilizando proxy reverso NGINX)
              cd /opt/lumina-frontend
              sed -i "s|export const API_BASE_URL = .*;|export const API_BASE_URL = '';|g" src/api/config.js 2>/dev/null || true

              # Instalação das dependências e build estático com Vite
              npm install --legacy-peer-deps
              npm run build

              # Copiar bundle final para o diretório web do NGINX
              rm -rf /var/www/html/*
              cp -r dist/* /var/www/html/
              chown -R www-data:www-data /var/www/html
              chmod -R 755 /var/www/html

              # Recarregar NGINX com a aplicacao React construida
              systemctl reload nginx
              EOF

  tags = {
    Name = "${var.project_name}-public-frontend-react-az-b"
    Tier = "Frontend"
    Type = "Public"
    AZ   = var.availability_zones[1]
  }
}


# Backend na Zona de Disponibilidade A (Sub-rede privada 1)
resource "aws_instance" "backend_a" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_backend
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name
  key_name               = var.ssh_key_name != "" ? var.ssh_key_name : null

  user_data = <<-EOF
              #!/bin/bash
              set -e
              export DEBIAN_FRONTEND=noninteractive

              # Log de todo o processo de inicializacao
              exec > >(tee -a /var/log/backend-provision.log) 2>&1

              # Criar swapfile de 2GB para estabilidade durante build do Maven
              if ! swapon --show | grep -q "/swapfile"; then
                fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
              fi

              apt-get update -y
              apt-get install -y git openjdk-21-jdk maven

              # Clonar repositório Back-end da branch main
              mkdir -p /opt/lumina-backend
              git clone --depth 1 -b ${var.backend_repo_branch} ${var.backend_repo_url} /opt/lumina-backend

              # Configurar application.properties dinamicamente com os parâmetros do ambiente
              mkdir -p /opt/lumina-backend/src/main/resources
              cat << 'PROPS' > /opt/lumina-backend/src/main/resources/application.properties
              server.port=8080
              spring.application.name=lumina-backend

              # Configuração DataSource MySQL
              spring.datasource.url=jdbc:mysql://${aws_instance.database_a.private_ip}:3306/${var.db_name}?createDatabaseIfNotExist=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=America/Sao_Paulo
              spring.datasource.username=${var.db_user}
              spring.datasource.password=${var.db_password}
              spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver

              # JPA e Hibernate
              spring.jpa.hibernate.ddl-auto=update
              spring.jpa.show-sql=false
              spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MySQLDialect

              # Segurança JWT
              jwt.secret=${var.jwt_secret}
              jwt.validity=${var.jwt_validity}

              # Google Gemini AI
              gemini.api.key=${var.gemini_api_key}

              # Actuator Health Check
              management.endpoints.web.exposure.include=*
              management.endpoint.health.show-details=always
              PROPS

              # Compilar e empacotar aplicação Java Spring Boot
              cd /opt/lumina-backend
              mvn clean package -DskipTests

              # Criar serviço systemd para manter a API Spring Boot em execução contínua
              cat << 'SERVICE' > /etc/systemd/system/lumina-backend.service
              [Unit]
              Description=Lumina Backend Spring Boot API
              After=syslog.target network.target

              [Service]
              Type=simple
              User=root
              WorkingDirectory=/opt/lumina-backend
              ExecStart=/usr/bin/java -jar /opt/lumina-backend/target/backend-0.0.1-SNAPSHOT.jar
              Restart=always
              RestartSec=10
              StandardOutput=journal
              StandardError=journal

              [Install]
              WantedBy=multi-user.target
              SERVICE

              systemctl daemon-reload
              systemctl enable lumina-backend
              systemctl start lumina-backend
              EOF

  depends_on = [
    aws_instance.database_a,
    aws_route_table_association.private_1
  ]

  tags = {
    Name = "${var.project_name}-private-backend-spring-az-a"
    Tier = "Backend"
    Type = "Private"
    AZ   = var.availability_zones[0]
  }
}

# Backend na Zona de Disponibilidade B (Sub-rede privada 2)
resource "aws_instance" "backend_b" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_backend
  subnet_id              = aws_subnet.private_2.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name
  key_name               = var.ssh_key_name != "" ? var.ssh_key_name : null

  user_data = <<-EOF
              #!/bin/bash
              set -e
              export DEBIAN_FRONTEND=noninteractive

              # Log de todo o processo de inicializacao
              exec > >(tee -a /var/log/backend-provision.log) 2>&1

              # Criar swapfile de 2GB para estabilidade durante build do Maven
              if ! swapon --show | grep -q "/swapfile"; then
                fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
              fi

              apt-get update -y
              apt-get install -y git openjdk-21-jdk maven

              # Clonar repositório Back-end da branch main
              mkdir -p /opt/lumina-backend
              git clone --depth 1 -b ${var.backend_repo_branch} ${var.backend_repo_url} /opt/lumina-backend

              # Configurar application.properties dinamicamente com os parâmetros do ambiente
              mkdir -p /opt/lumina-backend/src/main/resources
              cat << 'PROPS' > /opt/lumina-backend/src/main/resources/application.properties
              server.port=8080
              spring.application.name=lumina-backend

              # Configuração DataSource MySQL
              spring.datasource.url=jdbc:mysql://${aws_instance.database_a.private_ip}:3306/${var.db_name}?createDatabaseIfNotExist=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=America/Sao_Paulo
              spring.datasource.username=${var.db_user}
              spring.datasource.password=${var.db_password}
              spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver

              # JPA e Hibernate
              spring.jpa.hibernate.ddl-auto=update
              spring.jpa.show-sql=false
              spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MySQLDialect

              # Segurança JWT
              jwt.secret=${var.jwt_secret}
              jwt.validity=${var.jwt_validity}

              # Google Gemini AI
              gemini.api.key=${var.gemini_api_key}

              # Actuator Health Check
              management.endpoints.web.exposure.include=*
              management.endpoint.health.show-details=always
              PROPS

              # Compilar e empacotar aplicação Java Spring Boot
              cd /opt/lumina-backend
              mvn clean package -DskipTests

              # Criar serviço systemd para manter a API Spring Boot em execução contínua
              cat << 'SERVICE' > /etc/systemd/system/lumina-backend.service
              [Unit]
              Description=Lumina Backend Spring Boot API
              After=syslog.target network.target

              [Service]
              Type=simple
              User=root
              WorkingDirectory=/opt/lumina-backend
              ExecStart=/usr/bin/java -jar /opt/lumina-backend/target/backend-0.0.1-SNAPSHOT.jar
              Restart=always
              RestartSec=10
              StandardOutput=journal
              StandardError=journal

              [Install]
              WantedBy=multi-user.target
              SERVICE

              systemctl daemon-reload
              systemctl enable lumina-backend
              systemctl start lumina-backend
              EOF

  depends_on = [
    aws_instance.database_a,
    aws_route_table_association.private_2
  ]

  tags = {
    Name = "${var.project_name}-private-backend-spring-az-b"
    Tier = "Backend"
    Type = "Private"
    AZ   = var.availability_zones[1]
  }
}


# MySQL na Zona de Disponibilidade A (Sub-rede privada 3)
resource "aws_instance" "database_a" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_database
  subnet_id              = aws_subnet.private_3.id
  vpc_security_group_ids = [aws_security_group.database.id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name
  key_name               = var.ssh_key_name != "" ? var.ssh_key_name : null

  user_data = <<-EOF
              #!/bin/bash
              set -e
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get install -y mariadb-server nginx

              # Remover site padrão do NGINX
              rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default /etc/nginx/conf.d/default.conf

              # Configuração MariaDB/MySQL
              mkdir -p /etc/mysql/mariadb.conf.d
              cat << 'MYCNF' > /etc/mysql/mariadb.conf.d/99-lumina.cnf
              [mysqld]
              bind-address = 0.0.0.0
              max_connections = 500
              character-set-server = utf8mb4
              collation-server = utf8mb4_unicode_ci
              MYCNF

              systemctl restart mariadb
              systemctl enable mariadb

              # Criação do banco de dados e concessão de privilégios para a VPC
              mysql -u root << 'EOSQL'
              CREATE DATABASE IF NOT EXISTS ${var.db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
              CREATE USER IF NOT EXISTS '${var.db_user}'@'%' IDENTIFIED BY '${var.db_password}';
              GRANT ALL PRIVILEGES ON ${var.db_name}.* TO '${var.db_user}'@'%';
              FLUSH PRIVILEGES;
              EOSQL

              # Configura NGINX para monitoramento local do status
              cat << 'CONF' > /etc/nginx/conf.d/db_status.conf
              server {
                  listen 80;
                  server_name _;

                  location /status {
                      default_type application/json;
                      return 200 '{"database":"MySQL/MariaDB","status":"RUNNING","az":"${var.availability_zones[0]}"}';
                  }
              }
              CONF

              systemctl enable nginx
              systemctl restart nginx
              EOF

  tags = {
    Name = "${var.project_name}-private-database-mysql-az-a"
    Tier = "Database"
    Type = "Private"
    AZ   = var.availability_zones[0]
  }
}

# MySQL na Zona de Disponibilidade B (Sub-rede privada 4)
resource "aws_instance" "database_b" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_database
  subnet_id              = aws_subnet.private_4.id
  vpc_security_group_ids = [aws_security_group.database.id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name
  key_name               = var.ssh_key_name != "" ? var.ssh_key_name : null

  user_data = <<-EOF
              #!/bin/bash
              set -e
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get install -y mariadb-server nginx

              # Remover site padrão do NGINX
              rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default /etc/nginx/conf.d/default.conf

              # Configuração MariaDB/MySQL
              mkdir -p /etc/mysql/mariadb.conf.d
              cat << 'MYCNF' > /etc/mysql/mariadb.conf.d/99-lumina.cnf
              [mysqld]
              bind-address = 0.0.0.0
              max_connections = 500
              character-set-server = utf8mb4
              collation-server = utf8mb4_unicode_ci
              MYCNF

              systemctl restart mariadb
              systemctl enable mariadb

              # Criação do banco de dados e concessão de privilégios para a VPC
              mysql -u root << 'EOSQL'
              CREATE DATABASE IF NOT EXISTS ${var.db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
              CREATE USER IF NOT EXISTS '${var.db_user}'@'%' IDENTIFIED BY '${var.db_password}';
              GRANT ALL PRIVILEGES ON ${var.db_name}.* TO '${var.db_user}'@'%';
              FLUSH PRIVILEGES;
              EOSQL

              # Configura NGINX para monitoramento local do status
              cat << 'CONF' > /etc/nginx/conf.d/db_status.conf
              server {
                  listen 80;
                  server_name _;

                  location /status {
                      default_type application/json;
                      return 200 '{"database":"MySQL/MariaDB","status":"RUNNING","az":"${var.availability_zones[1]}"}';
                  }
              }
              CONF

              systemctl enable nginx
              systemctl restart nginx
              EOF

  tags = {
    Name = "${var.project_name}-private-database-mysql-az-b"
    Tier = "Database"
    Type = "Private"
    AZ   = var.availability_zones[1]
  }
}


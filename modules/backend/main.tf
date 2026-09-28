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

resource "aws_instance" "backend" {
  count                  = var.instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name
  key_name               = var.key_name != "" ? var.key_name : null

  associate_public_ip_address = var.is_dev

  user_data = <<-EOF
              #!/bin/bash
              set -e
              export DEBIAN_FRONTEND=noninteractive

              exec > >(tee -a /var/log/backend-provision.log) 2>&1

              # Criar swapfile de 2GB para estabilidade do build Maven
              if ! swapon --show | grep -q "/swapfile"; then
                fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
              fi

              apt-get update -y
              apt-get install -y git openjdk-21-jdk maven

              # Clonar repositorio Back-end
              mkdir -p /opt/lumina-backend
              git clone --depth 1 -b ${var.backend_repo_branch} ${var.backend_repo_url} /opt/lumina-backend || git clone --depth 1 ${var.backend_repo_url} /opt/lumina-backend

              # Configurar application.properties dinamicamente (Lumina case-sensitive)
              mkdir -p /opt/lumina-backend/src/main/resources
              cat << 'PROPS' > /opt/lumina-backend/src/main/resources/application.properties
              server.port=8080
              spring.application.name=lumina-backend

              # Configuracao DataSource MySQL
              spring.datasource.url=jdbc:mysql://${var.db_private_ip}:3306/${var.db_name}?createDatabaseIfNotExist=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=America/Sao_Paulo
              spring.datasource.username=${var.db_user}
              spring.datasource.password=${var.db_password}
              spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver

              # JPA e Hibernate
              spring.jpa.hibernate.ddl-auto=update
              spring.jpa.show-sql=false
              spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MySQLDialect

              # Seguranca JWT
              jwt.secret=${var.jwt_secret}
              jwt.validity=${var.jwt_validity}

              # Google Gemini AI
              gemini.api.key=${var.gemini_api_key}

              # Actuator Health Check
              management.endpoints.web.exposure.include=*
              management.endpoint.health.show-details=always
              PROPS

              # Compilar e empacotar aplicacao Spring Boot
              cd /opt/lumina-backend
              mvn clean package -DskipTests

              # Criar servico systemd lumina-backend
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

  tags = {
    Name        = "${var.project_name}-backend-${count.index + 1}-${var.environment}"
    Tier        = "Backend"
    Environment = var.environment
  }
}

locals {
  tg_attachments = flatten([
    for instance_idx, instance in aws_instance.backend : [
      for tg_idx, tg_arn in var.target_group_arns : {
        key       = "${instance_idx}-${tg_idx}"
        target_id = instance.id
        tg_arn    = tg_arn
      }
    ]
  ])
}

resource "aws_lb_target_group_attachment" "backend" {
  for_each         = { for item in local.tg_attachments : item.key => item }
  target_group_arn = each.value.tg_arn
  target_id        = each.value.target_id
  port             = 8080
}

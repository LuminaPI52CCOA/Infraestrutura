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

data "aws_caller_identity" "current" {}

data "aws_iam_instance_profile" "lab_profile" {
  name = var.lab_instance_profile_name
}

locals {
  database_image = var.ecr_image_url != "" ? var.ecr_image_url : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/lumina-database:latest"
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

              # 1. Instalar dependencias basicas, Docker Engine e Docker Compose
              apt-get update -y
              apt-get install -y ca-certificates curl gnupg jq awscli

              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
              chmod a+r /etc/apt/keyrings/docker.gpg

              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

              systemctl enable docker
              systemctl start docker

              mkdir -p /opt/lumina-database
              cd /opt/lumina-database

              # 2. Criar docker-compose.yml
              cat << 'COMPOSE' > /opt/lumina-database/docker-compose.yml
              services:
                mysql:
                  image: ${local.database_image}
                  container_name: lumina-mysql
                  restart: unless-stopped
                  environment:
                    MYSQL_ROOT_PASSWORD: ${var.db_password}
                    MYSQL_DATABASE: ${var.db_name}
                    MYSQL_USER: ${var.db_user}
                    MYSQL_PASSWORD: ${var.db_password}
                  ports:
                    - "3306:3306"
                  volumes:
                    - mysql_persistent_data:/var/lib/mysql

              volumes:
                mysql_persistent_data:
              COMPOSE

              # 3. Autenticar no Amazon ECR via IMDSv2 / LabRole
              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
              if [ -n "$TOKEN" ]; then
                REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
                ACCOUNT_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
              else
                REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
                ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
              fi

              aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $${ACCOUNT_ID}.dkr.ecr.$${REGION}.amazonaws.com || true

              # 4. Criar servico systemd lumina-docker para resiliencia no boot
              cat << 'SERVICE' > /etc/systemd/system/lumina-docker.service
              [Unit]
              Description=Lumina Database Docker Compose Application
              Requires=docker.service
              After=docker.service network-online.target

              [Service]
              Type=oneshot
              RemainAfterExit=yes
              WorkingDirectory=/opt/lumina-database
              ExecStart=/usr/bin/docker compose up -d
              ExecStop=/usr/bin/docker compose down
              TimeoutStartSec=0

              [Install]
              WantedBy=multi-user.target
              SERVICE

              systemctl daemon-reload
              systemctl enable lumina-docker
              systemctl start lumina-docker
              EOF

  tags = {
    Name        = "${var.project_name}-database-${count.index + 1}-${var.environment}"
    Tier        = "Database"
    Environment = var.environment
  }
}

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
  backend_image = var.ecr_image_url != "" ? var.ecr_image_url : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/lumina-backend:latest"
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

              mkdir -p /opt/lumina-backend
              cd /opt/lumina-backend

              # 2. Escrever arquivo de variaveis .env (com permissao restrita)
              cat << 'ENV' > /opt/lumina-backend/.env
              SPRING_DATASOURCE_URL=jdbc:mysql://${var.db_private_ip}:3306/${var.db_name}?createDatabaseIfNotExist=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=America/Sao_Paulo
              SPRING_DATASOURCE_USERNAME=${var.db_user}
              SPRING_DATASOURCE_PASSWORD=${var.db_password}
              JWT_SECRET=${var.jwt_secret}
              JWT_VALIDITY=${var.jwt_validity}
              GEMINI_API_KEY=${var.gemini_api_key}
              ALEXA_LWA_CLIENT_ID=${var.alexa_lwa_client_id}
              ALEXA_LWA_CLIENT_SECRET=${var.alexa_lwa_client_secret}
              AWS_REGION=${var.aws_region}
              AWS_S3_BUCKET_NAME=${var.s3_bucket_name}
              BUCKET_BRONZE=${var.s3_bronze_bucket_name}
              ENVIRONMENT=${var.environment}
              ENV
              chmod 600 /opt/lumina-backend/.env

              # 3. Configuracao do Fluent Bit (fluent-bit.conf e parsers.conf)
              cat << 'FBCONF' > /opt/lumina-backend/fluent-bit.conf
              [SERVICE]
                  Flush        1
                  Daemon       Off
                  Log_Level    info
                  Parsers_File parsers.conf
                  HTTP_Server  On
                  HTTP_Listen  0.0.0.0
                  HTTP_Port    2020
                  Storage.path /tmp/fluent-bit/storage
                  Storage.sync normal

              [INPUT]
                  Name             tail
                  Tag              containers.docker
                  Path             /var/lib/docker/containers/*/*.log,/var/log/containers/*.log
                  Parser           docker
                  Mem_Buf_Limit    10MB
                  Refresh_Interval 5
                  Skip_Long_Lines  On
                  DB               /tmp/fluent-bit/tail-containers.db

              [INPUT]
                  Name             tail
                  Tag              app.backend
                  Path             /var/log/backend/*.log
                  Parser           spring_boot
                  Mem_Buf_Limit    10MB
                  Refresh_Interval 5
                  DB               /tmp/fluent-bit/tail-backend.db

              [FILTER]
                  Name         record_modifier
                  Match        *
                  Record       project lumina
                  Record       tier bronze
                  Record       environment ${var.environment}

              [OUTPUT]
                  Name            s3
                  Match           containers.*
                  region          ${var.aws_region}
                  bucket          ${var.s3_bronze_bucket_name}
                  total_file_size 10M
                  upload_timeout  1m
                  use_put_object  On
                  compression     gzip
                  s3_key_format   /logs/containers/%Y/%m/%d/$TAG-$UUID.json.gz
                  store_dir       /tmp/fluent-bit/s3

              [OUTPUT]
                  Name            s3
                  Match           app.backend
                  region          ${var.aws_region}
                  bucket          ${var.s3_bronze_bucket_name}
                  total_file_size 10M
                  upload_timeout  1m
                  use_put_object  On
                  compression     gzip
                  s3_key_format   /logs/backend/%Y/%m/%d/$TAG-$UUID.json.gz
                  store_dir       /tmp/fluent-bit/s3

              [OUTPUT]
                  Name            stdout
                  Match           *
                  Format          json_lines
              FBCONF

              cat << 'PARSERS' > /opt/lumina-backend/parsers.conf
              [PARSER]
                  Name        json
                  Format      json
                  Time_Key    time
                  Time_Format %Y-%m-%dT%H:%M:%S.%L
                  Time_Keep   On

              [PARSER]
                  Name        docker
                  Format      json
                  Time_Key    time
                  Time_Format %Y-%m-%dT%H:%M:%S.%L%z
                  Time_Keep   On

              [PARSER]
                  Name        spring_boot
                  Format      regex
                  Regex       ^(?<time>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}(?:Z|[+-]\d{2}:\d{2}))\s+(?<level>[A-Z]+)\s+(?<pid>\d+)\s+---\s+\[(?<service>[^\]]*)\]\s+\[(?<thread>[^\]]*)\]\s+(?<logger>[^\s]+)\s*:\s*(?<message>.*)$
              PARSERS

              # 4. Criar docker-compose.yml
              cat << 'COMPOSE' > /opt/lumina-backend/docker-compose.yml
              services:
                backend:
                  image: ${local.backend_image}
                  container_name: lumina-backend
                  restart: unless-stopped
                  env_file: .env
                  ports:
                    - "8080:8080"
                  volumes:
                    - backend_logs:/var/log/backend
                  environment:
                    - LOGGING_FILE_NAME=/var/log/backend/app.log
                    - "LOGGING_PATTERN_FILE=%d{yyyy-MM-dd'T'HH:mm:ss.SSSXXX} %-5level %pid --- [%t] %-40.40logger{39} : %m%n"

                fluent-bit:
                  image: fluent/fluent-bit:latest
                  container_name: lumina-fluent-bit
                  restart: unless-stopped
                  depends_on:
                    - backend
                  environment:
                    - AWS_REGION=${var.aws_region}
                    - BUCKET_BRONZE=${var.s3_bronze_bucket_name}
                    - ENVIRONMENT=${var.environment}
                  ports:
                    - "2020:2020"
                  volumes:
                    - ./fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf:ro
                    - ./parsers.conf:/fluent-bit/etc/parsers.conf:ro
                    - backend_logs:/var/log/backend:ro
                    - /var/lib/docker/containers:/var/lib/docker/containers:ro
                    - /var/run/docker.sock:/var/run/docker.sock:ro

                watchtower:
                  image: containrrr/watchtower:latest
                  container_name: lumina-watchtower
                  restart: unless-stopped
                  environment:
                    - AWS_REGION=${var.aws_region}
                    - WATCHTOWER_POLL_INTERVAL=20
                    - WATCHTOWER_CLEANUP=true
                    - WATCHTOWER_ROLLING_RESTART=true
                  volumes:
                    - /var/run/docker.sock:/var/run/docker.sock

              volumes:
                backend_logs:
              COMPOSE

              # 5. Autenticar no Amazon ECR via IMDSv2 / LabRole
              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
              if [ -n "$TOKEN" ]; then
                REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
                ACCOUNT_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
              else
                REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
                ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
              fi

              aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $${ACCOUNT_ID}.dkr.ecr.$${REGION}.amazonaws.com || true

              # 6. Criar servico systemd lumina-docker para resiliencia no boot
              cat << 'SERVICE' > /etc/systemd/system/lumina-docker.service
              [Unit]
              Description=Lumina Backend Docker Compose Application
              Requires=docker.service
              After=docker.service network-online.target

              [Service]
              Type=oneshot
              RemainAfterExit=yes
              WorkingDirectory=/opt/lumina-backend
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

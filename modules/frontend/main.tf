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
  frontend_image = var.ecr_image_url != "" ? var.ecr_image_url : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/lumina-frontend:latest"
}

resource "aws_instance" "frontend" {
  count                  = var.instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name
  key_name               = var.key_name != "" ? var.key_name : null

  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              set -e
              export DEBIAN_FRONTEND=noninteractive

              exec > >(tee -a /var/log/frontend-provision.log) 2>&1

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

              mkdir -p /opt/lumina-frontend
              cd /opt/lumina-frontend

              # 2. Configuracao do NGINX com Proxy Reverso Completo apontando para o backend
              cat << 'CONF' > /opt/lumina-frontend/nginx.conf
              server {
                  listen 80 default_server;
                  server_name _;

                  # Redirecionamento de /api/ para o backend (removendo o prefixo /api/)
                  location /api/ {
                      proxy_pass http://${var.backend_endpoint}:8080/;
                      proxy_http_version 1.1;
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;
                      proxy_connect_timeout 60s;
                      proxy_read_timeout 60s;
                  }

                  # Proxy reverso para APIs e Swagger acessados diretamente na raiz
                  location ~ ^/(tipos-midia|alexa|usuarios|clientes|consultas|convenios|anamnese|anamneses|perfis|especialidades|swagger-ui|v3|actuator) {
                      proxy_pass http://${var.backend_endpoint}:8080;
                      proxy_http_version 1.1;
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;
                      proxy_connect_timeout 60s;
                      proxy_read_timeout 60s;
                  }

                  # Tratamento para SPA React
                  location / {
                      root /usr/share/nginx/html;
                      index index.html;
                      try_files $uri $uri/ /index.html;
                  }
              }
              CONF

              # 3. Criar docker-compose.yml
              cat << 'COMPOSE' > /opt/lumina-frontend/docker-compose.yml
              services:
                frontend:
                  image: ${local.frontend_image}
                  container_name: lumina-frontend
                  restart: unless-stopped
                  ports:
                    - "80:80"
                  volumes:
                    - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro

                watchtower:
                  image: containrrr/watchtower:latest
                  container_name: lumina-frontend-watchtower
                  restart: unless-stopped
                  environment:
                    - AWS_REGION=${var.aws_region}
                    - WATCHTOWER_POLL_INTERVAL=20
                    - WATCHTOWER_CLEANUP=true
                    - WATCHTOWER_ROLLING_RESTART=true
                  volumes:
                    - /var/run/docker.sock:/var/run/docker.sock
              COMPOSE

              # 4. Autenticar no Amazon ECR via IMDSv2 / LabRole
              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
              if [ -n "$TOKEN" ]; then
                REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
                ACCOUNT_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
              else
                REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
                ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
              fi

              aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $${ACCOUNT_ID}.dkr.ecr.$${REGION}.amazonaws.com || true

              # 5. Criar servico systemd lumina-docker para resiliencia no boot
              cat << 'SERVICE' > /etc/systemd/system/lumina-docker.service
              [Unit]
              Description=Lumina Frontend Docker Compose Application
              Requires=docker.service
              After=docker.service network-online.target

              [Service]
              Type=oneshot
              RemainAfterExit=yes
              WorkingDirectory=/opt/lumina-frontend
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
    Name        = "${var.project_name}-frontend-${count.index + 1}-${var.environment}"
    Tier        = "Frontend"
    Environment = var.environment
  }
}

locals {
  tg_attachments = flatten([
    for instance_idx, instance in aws_instance.frontend : [
      for tg_idx, tg_arn in var.target_group_arns : {
        key       = "${instance_idx}-${tg_idx}"
        target_id = instance.id
        tg_arn    = tg_arn
      }
    ]
  ])
}

resource "aws_lb_target_group_attachment" "frontend" {
  for_each         = { for item in local.tg_attachments : item.key => item }
  target_group_arn = each.value.tg_arn
  target_id        = each.value.target_id
  port             = 80
}

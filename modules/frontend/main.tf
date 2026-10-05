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

              # Criar swapfile de 2GB para estabilidade do build Vite em t3.micro
              if ! swapon --show | grep -q "/swapfile"; then
                fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
              fi

              apt-get update -y
              apt-get install -y curl ca-certificates gnupg git nginx

              # Pagina temporaria para passar imediatamente no ALB Health Check
              rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default /etc/nginx/conf.d/default.conf
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

              # Configuracao do NGINX com Proxy Reverso Completo (INCLUINDO /alexa)
              cat << 'CONF' > /etc/nginx/sites-available/lumina-frontend.conf
              server {
                  listen 80 default_server;
                  server_name _;
                  root /var/www/html;
                  index index.html;

                  location / {
                      try_files $uri $uri/ /index.html;
                  }

                  # Proxy reverso para APIs e Alexa Skills
                  location ~ ^/(alexa|usuarios|clientes|consultas|convenios|anamnese|perfis|swagger-ui|v3|actuator|api) {
                      proxy_pass http://${var.backend_endpoint}:8080;
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

              # Instalar Node.js 20 LTS oficial
              curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
              apt-get install -y nodejs

              # Clonar repositorio Front-End
              rm -rf /opt/lumina-frontend
              mkdir -p /opt/lumina-frontend
              git clone --depth 1 -b ${var.frontend_repo_branch} ${var.frontend_repo_url} /opt/lumina-frontend || git clone --depth 1 ${var.frontend_repo_url} /opt/lumina-frontend

              # Ajustar API_BASE_URL para caminhos relativos
              cd /opt/lumina-frontend
              sed -i "s|export const API_BASE_URL = .*;|export const API_BASE_URL = '';|g" src/api/config.js 2>/dev/null || true

              # Build estatico Vite
              npm install --legacy-peer-deps react-is || npm install --legacy-peer-deps
              if npm run build; then
                # Copiar bundle para o diretorio web do NGINX
                rm -rf /var/www/html/*
                cp -r dist/* /var/www/html/
                chown -R www-data:www-data /var/www/html
                chmod -R 755 /var/www/html
                systemctl reload nginx
                echo "Frontend React/Vite implantado com sucesso!"
              else
                echo "Falha no build do Vite! Gerando pagina de erro informativa."
                cat << 'ERRHTML' > /var/www/html/index.html
              <!DOCTYPE html>
              <html>
              <head><meta charset="utf-8"><title>Lumina - Erro no Build</title></head>
              <body style="font-family:sans-serif;text-align:center;padding:50px;background:#0f172a;color:#f87171;">
                <h1>❌ Erro na Compilação do Frontend</h1>
                <p style="color:#cbd5e1;">Ocorreu uma falha durante o <code>npm run build</code>. Verifique <code>/var/log/frontend-provision.log</code> na instância EC2.</p>
              </body>
              </html>
              ERRHTML
                systemctl reload nginx
                exit 1
              fi
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

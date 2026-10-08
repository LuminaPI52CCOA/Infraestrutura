# ==============================================================================
# Ambiente Prod (Modo Apresentacao / Banca - Multi-AZ, 7 Instancias, NAT, 2 ALBs, EFS)
# ==============================================================================

module "keypair" {
  source     = "../../modules/keypair"
  key_name   = var.ssh_key_name
  public_key = var.ssh_public_key
}

module "network" {
  source              = "../../modules/network"
  project_name        = var.project_name
  environment         = "prod"
  is_dev              = false
  enable_nat_gateway  = true
  enable_internal_alb = true
}

module "database" {
  source                      = "../../modules/database"
  project_name                = var.project_name
  environment                 = "prod"
  instance_count              = 2
  instance_type               = var.instance_type_database
  subnet_ids                  = module.network.private_db_subnet_ids
  security_group_ids          = [module.network.sg_database_id]
  key_name                    = module.keypair.key_name
  db_name                     = var.db_name
  db_user                     = var.db_user
  db_password                 = var.db_password
  db_repo_url                 = var.db_repo_url
  db_repo_branch              = var.db_repo_branch
  associate_public_ip_address = false
}

module "backend" {
  source                  = "../../modules/backend"
  project_name            = var.project_name
  environment             = "prod"
  is_dev                  = false
  instance_count          = 2
  instance_type           = var.instance_type_backend
  subnet_ids              = module.network.private_app_subnet_ids
  security_group_ids      = [module.network.sg_backend_id]
  key_name                = module.keypair.key_name
  db_private_ip           = module.database.primary_private_ip
  db_name                 = var.db_name
  db_user                 = var.db_user
  db_password             = var.db_password
  jwt_secret              = var.jwt_secret
  jwt_validity            = var.jwt_validity
  gemini_api_key          = var.gemini_api_key
  alexa_lwa_client_id     = var.alexa_lwa_client_id
  alexa_lwa_client_secret = var.alexa_lwa_client_secret
  alexa_reminders_enabled = var.alexa_reminders_enabled
  backend_repo_url        = var.backend_repo_url
  backend_repo_branch     = var.backend_repo_branch
  target_group_arns       = [module.network.alb_internal_tg_backend_arn]
}

module "frontend" {
  source               = "../../modules/frontend"
  project_name         = var.project_name
  environment          = "prod"
  instance_count       = 2
  instance_type        = var.instance_type_frontend
  subnet_ids           = module.network.public_subnet_ids
  security_group_ids   = [module.network.sg_frontend_id]
  key_name             = module.keypair.key_name
  backend_endpoint     = module.network.alb_internal_dns
  frontend_repo_url    = var.frontend_repo_url
  frontend_repo_branch = var.frontend_repo_branch
  target_group_arns    = [module.network.alb_public_tg_frontend_arn]
}

# ==============================================================================
# Bastion Host (Jump Host na Sub-rede Publica 2 - Zona B)
# ==============================================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_bastion
  subnet_id                   = module.network.public_subnet_ids[1]
  vpc_security_group_ids      = [module.network.sg_bastion_id]
  key_name                    = module.keypair.key_name
  iam_instance_profile        = "LabInstanceProfile"
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              set -e
              apt-get update -y
              apt-get install -y nginx
              systemctl enable nginx
              systemctl start nginx
              EOF

  tags = {
    Name        = "${var.project_name}-bastion-host-prod"
    Role        = "Bastion"
    Tier        = "Admin"
    Environment = "prod"
  }
}

# ==============================================================================
# Amazon EFS (Elastic File System) Compartilhado para Multi-AZ
# ==============================================================================

resource "aws_efs_file_system" "shared_fs" {
  creation_token   = "${var.project_name}-efs-prod"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = {
    Name        = "${var.project_name}-efs-prod"
    Environment = "prod"
  }
}

resource "aws_efs_mount_target" "mount_a" {
  file_system_id  = aws_efs_file_system.shared_fs.id
  subnet_id       = module.network.private_db_subnet_ids[0]
  security_groups = [module.network.sg_efs_id]
}

resource "aws_efs_mount_target" "mount_b" {
  file_system_id  = aws_efs_file_system.shared_fs.id
  subnet_id       = module.network.private_db_subnet_ids[1]
  security_groups = [module.network.sg_efs_id]
}

# ==============================================================================
# Modulo Serverless Alexa
# ==============================================================================

module "alexa" {
  source           = "../../../Lambda-Alexa/terraform"
  function_name    = var.alexa_function_name
  backend_url      = "http://${module.network.alb_public_dns}"
  service_email    = var.alexa_service_email
  service_password = var.alexa_service_password
  alexa_skill_id   = var.alexa_skill_id
}

# ==============================================================================
# Pipeline de Dados (Bronze -> Silver -> Gold)
# ==============================================================================

module "s3_bronze" {
  source                    = "../../modules/s3"
  bucket_name               = "lumina-bronze"
  enable_event_notification = true
}

module "s3_silver" {
  source      = "../../modules/s3"
  bucket_name = "lumina-silver"
}

module "s3_gold" {
  source      = "../../modules/s3"
  bucket_name = "lumina-gold"
}

module "s3_athena_results" {
  source      = "../../modules/s3"
  bucket_name = "lumina-athena-results"
}

module "data_pipeline" {
  source             = "../../../Data-Pipeline/terraform"
  project_name       = var.project_name
  environment        = "prod"
  bucket_bronze_name = module.s3_bronze.bucket_name
  bucket_silver_name = module.s3_silver.bucket_name
  script_bucket_id   = module.s3_athena_results.bucket_id
  enable_s3_trigger  = true
}

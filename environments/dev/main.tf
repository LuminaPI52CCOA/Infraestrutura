# ==============================================================================
# Ambiente Dev (Modo Economico - Single-AZ, 3 Instancias, Sem NAT Gateway)
# ==============================================================================

module "keypair" {
  source     = "../../modules/keypair"
  key_name   = var.ssh_key_name
  public_key = var.ssh_public_key
}

module "network" {
  source              = "../../modules/network"
  project_name        = var.project_name
  environment         = "dev"
  is_dev              = true
  enable_nat_gateway  = false
  enable_internal_alb = false
}

module "database" {
  source                      = "../../modules/database"
  project_name                = var.project_name
  environment                 = "dev"
  instance_count              = 1
  instance_type               = var.instance_type_database
  subnet_ids                  = [module.network.public_subnet_ids[0]]
  security_group_ids          = [module.network.sg_database_id]
  key_name                    = module.keypair.key_name
  db_name                     = var.db_name
  db_user                     = var.db_user
  db_password                 = var.db_password
  db_repo_url                 = var.db_repo_url
  db_repo_branch              = var.db_repo_branch
  associate_public_ip_address = true
}

module "backend" {
  source              = "../../modules/backend"
  project_name        = var.project_name
  environment         = "dev"
  is_dev              = true
  instance_count      = 1
  instance_type       = var.instance_type_backend
  subnet_ids          = [module.network.public_subnet_ids[0]]
  security_group_ids  = [module.network.sg_backend_id]
  key_name            = module.keypair.key_name
  db_private_ip       = module.database.primary_private_ip
  db_name             = var.db_name
  db_user             = var.db_user
  db_password         = var.db_password
  jwt_secret          = var.jwt_secret
  jwt_validity        = var.jwt_validity
  gemini_api_key      = var.gemini_api_key
  backend_repo_url    = var.backend_repo_url
  backend_repo_branch = var.backend_repo_branch
}

module "frontend" {
  source               = "../../modules/frontend"
  project_name         = var.project_name
  environment          = "dev"
  instance_count       = 1
  instance_type        = var.instance_type_frontend
  subnet_ids           = [module.network.public_subnet_ids[0]]
  security_group_ids   = [module.network.sg_frontend_id]
  key_name             = module.keypair.key_name
  backend_endpoint     = module.backend.primary_private_ip
  frontend_repo_url    = var.frontend_repo_url
  frontend_repo_branch = var.frontend_repo_branch
  target_group_arns    = [module.network.alb_public_tg_frontend_arn]
}

module "alexa" {
  source           = "../../../Lambda-Alexa/terraform"
  function_name    = var.alexa_function_name
  backend_url      = "http://${module.network.alb_public_dns}"
  service_email    = var.alexa_service_email
  service_password = var.alexa_service_password
  alexa_skill_id   = var.alexa_skill_id
}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
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

module "lambda_extracao" {
  source              = "../../modules/lambda"
  function_name       = "${var.project_name}-extracao-sisagua"
  role_arn            = data.aws_iam_role.lab_role.arn
  source_dir          = "${path.module}/src/lambda_extracao"
  schedule_expression = "cron(0 3 * * ? *)" # 3 AM daily
  timeout             = 120
  memory_size         = 256
  environment_variables = {
    BUCKET_BRONZE = module.s3_bronze.bucket_name
  }
}

module "glue_transformacao" {
  source              = "../../modules/glue"
  job_name            = "${var.project_name}-bronze-to-silver"
  role_arn            = data.aws_iam_role.lab_role.arn
  script_bucket_id    = module.s3_athena_results.bucket_id
  script_source_path  = "${path.module}/src/glue_transformacao/job.py"
  trigger_bucket_name = module.s3_bronze.bucket_name
  default_arguments = {
    "--JOB_NAME"      = "${var.project_name}-bronze-to-silver"
    "--BUCKET_BRONZE" = "s3://${module.s3_bronze.bucket_name}"
    "--BUCKET_SILVER" = "s3://${module.s3_silver.bucket_name}"
  }
}

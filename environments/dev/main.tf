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

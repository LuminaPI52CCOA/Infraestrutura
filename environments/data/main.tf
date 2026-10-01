# ==============================================================================
# Ambiente Isolado de Pipeline de Dados (Bronze -> Silver -> Gold + ETL)
# Sem EC2, sem ALBs, sem Banco Relacional. Zero custos de maquinas virtuais.
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
  environment        = var.environment
  bucket_bronze_name = module.s3_bronze.bucket_name
  bucket_silver_name = module.s3_silver.bucket_name
  script_bucket_id   = module.s3_athena_results.bucket_id
  enable_s3_trigger  = var.enable_s3_trigger
}

# ==============================================================================
# Ambiente Isolado de Pipeline de Dados (Bronze -> Silver -> Gold + ETL)
# Sem EC2, sem ALBs, sem Banco Relacional. Zero custos de maquinas virtuais.
# ==============================================================================

module "s3_bronze" {
  source                    = "../../modules/s3"
  bucket_name               = "lumina-sptech-bronze"
  enable_event_notification = true
}

module "s3_silver" {
  source      = "../../modules/s3"
  bucket_name = "lumina-sptech-silver"
}

module "s3_gold" {
  source      = "../../modules/s3"
  bucket_name = "lumina-sptech-gold"
}

module "s3_athena_results" {
  source      = "../../modules/s3"
  bucket_name = "lumina-sptech-athena-results"
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

# ==============================================================================
# Pipeline Dedicado aos Logs (Fluent Bit -> Bronze -> Silver -> Athena)
# ==============================================================================

resource "aws_athena_database" "logs_db" {
  name   = "lumina_logs_db"
  bucket = module.s3_athena_results.bucket_id

  comment = "Banco de dados analitico dedicado a telemetria e logs processados pelo AWS Glue"
}

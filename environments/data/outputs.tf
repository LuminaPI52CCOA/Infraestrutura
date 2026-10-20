output "bucket_bronze_name" {
  description = "Nome do Bucket S3 Bronze"
  value       = module.s3_bronze.bucket_name
}

output "bucket_silver_name" {
  description = "Nome do Bucket S3 Silver"
  value       = module.s3_silver.bucket_name
}

output "bucket_gold_name" {
  description = "Nome do Bucket S3 Gold"
  value       = module.s3_gold.bucket_name
}

output "bucket_athena_results_name" {
  description = "Nome do Bucket S3 Athena Results"
  value       = module.s3_athena_results.bucket_name
}

output "lambda_extracao_name" {
  description = "Nome da funcao Lambda de extracao SISAGUA"
  value       = module.data_pipeline.lambda_extracao_name
}

output "lambda_extracao_arn" {
  description = "ARN da funcao Lambda de extracao SISAGUA"
  value       = module.data_pipeline.lambda_extracao_arn
}

output "glue_job_name" {
  description = "Nome do Glue Job de transformacao"
  value       = module.data_pipeline.glue_job_name
}

output "glue_job_arn" {
  description = "ARN do Glue Job de transformacao"
  value       = module.data_pipeline.glue_job_arn
}

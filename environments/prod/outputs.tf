output "alb_public_dns" {
  description = "DNS publico do ALB para acesso ao frontend e endpoints externos"
  value       = module.network.alb_public_dns
}

output "alb_internal_dns" {
  description = "DNS interno do ALB para distribuicao de carga na camada backend"
  value       = module.network.alb_internal_dns
}

output "bastion_public_ip" {
  description = "IP publico do Bastion Host para saltos SSH administrativos"
  value       = aws_instance.bastion.public_ip
}

output "frontend_private_ips" {
  description = "IPs privados das instancias frontend"
  value       = module.frontend.private_ips
}

output "backend_private_ips" {
  description = "IPs privados das instancias backend"
  value       = module.backend.private_ips
}

output "database_private_ips" {
  description = "IPs privados das instancias database"
  value       = module.database.private_ips
}

output "lambda_arn" {
  description = "ARN da funcao Lambda da Skill Alexa"
  value       = module.alexa.lambda_arn
}

output "lambda_function_name" {
  description = "Nome da funcao Lambda da Skill Alexa"
  value       = module.alexa.function_name
}

output "alb_public_dns" {
  description = "DNS publico do ALB para acesso ao sistema e a API"
  value       = module.network.alb_public_dns
}

output "frontend_public_ip" {
  description = "IP publico da EC2 Frontend"
  value       = module.frontend.primary_public_ip
}

output "backend_public_ip" {
  description = "IP publico da EC2 Backend (disponivel em dev para CD/SSH)"
  value       = module.backend.primary_public_ip
}

output "backend_private_ip" {
  description = "IP privado da EC2 Backend"
  value       = module.backend.primary_private_ip
}

output "database_private_ip" {
  description = "IP privado da EC2 Database"
  value       = module.database.primary_private_ip
}

output "lambda_arn" {
  description = "ARN da funcao Lambda da Skill Alexa"
  value       = module.alexa.lambda_arn
}

output "lambda_function_name" {
  description = "Nome da funcao Lambda da Skill Alexa"
  value       = module.alexa.function_name
}

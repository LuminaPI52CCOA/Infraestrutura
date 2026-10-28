output "repository_urls" {
  description = "URLs dos repositorios ECR criados"
  value       = { for k, v in aws_ecr_repository.lumina_repos : k => v.repository_url }
}

output "backend_repository_url" {
  description = "URL do repositorio ECR do backend"
  value       = aws_ecr_repository.lumina_repos["lumina-backend"].repository_url
}

output "frontend_repository_url" {
  description = "URL do repositorio ECR do frontend"
  value       = aws_ecr_repository.lumina_repos["lumina-frontend"].repository_url
}

output "database_repository_url" {
  description = "URL do repositorio ECR do banco de dados"
  value       = aws_ecr_repository.lumina_repos["lumina-database"].repository_url
}

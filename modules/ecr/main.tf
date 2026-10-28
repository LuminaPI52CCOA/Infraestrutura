resource "aws_ecr_repository" "lumina_repos" {
  for_each             = toset(["lumina-backend", "lumina-frontend", "lumina-database"])
  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false # Economia de chamadas de API no laboratorio
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "lumina_cleanup" {
  for_each   = aws_ecr_repository.lumina_repos
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Manter apenas 1 imagem com tag para economizar espaco no lab"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "lumina"
}

variable "environment" {
  description = "Ambiente de deploy (dev/prod)"
  type        = string
}

variable "aws_region" {
  description = "Regiao da AWS onde a infraestrutura sera provisionada"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto para identificacao dos recursos"
  type        = string
  default     = "lumina"
}

variable "environment" {
  description = "Identificador do ambiente"
  type        = string
  default     = "data"
}

variable "enable_s3_trigger" {
  description = "Habilitar acionamento automatico do Glue Job pelo EventBridge"
  type        = bool
  default     = true
}

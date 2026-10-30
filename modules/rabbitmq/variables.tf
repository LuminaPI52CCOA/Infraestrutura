variable "project_name" {
  description = "Prefixo do projeto"
  type        = string
  default     = "lumina"
}

variable "environment" {
  description = "Ambiente (dev ou prod)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "subnet_ids" {
  description = "Lista de IDs das sub-redes para alocação da Task Fargate"
  type        = list(string)
}

variable "backend_sg_id" {
  description = "ID do Security Group do Backend para autorizar tráfego na porta 5672"
  type        = string
}

variable "ecr_image_url" {
  description = "URL da imagem RabbitMQ no ECR (com fallback para rabbitmq:3.13-management-alpine)"
  type        = string
  default     = ""
}

variable "rabbitmq_user" {
  description = "Usuario padrao do RabbitMQ"
  type        = string
  default     = "guest"
}

variable "rabbitmq_password" {
  description = "Senha padrao do RabbitMQ"
  type        = string
  sensitive   = true
  default     = "guest"
}

variable "lab_role_name" {
  description = "Nome da role IAM padrao do AWS Academy Learner Lab"
  type        = string
  default     = "LabRole"
}

variable "is_dev" {
  description = "Flag de modo dev (atribui IP publico para download da imagem caso nao haja NAT Gateway)"
  type        = bool
  default     = true
}

variable "cpu" {
  description = "CPU alocada para a Task Fargate"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memoria em MB para a Task Fargate"
  type        = number
  default     = 512
}

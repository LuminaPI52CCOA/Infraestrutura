variable "project_name" {
  description = "Prefixo para identificacao e tags dos recursos"
  type        = string
  default     = "lumina"
}

variable "environment" {
  description = "Perfil de ambiente (dev ou prod)"
  type        = string
  default     = "dev"
}

variable "instance_count" {
  description = "Quantidade de instancias frontend (1 em dev, 2 em prod)"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "subnet_ids" {
  description = "Lista de IDs de sub-rede publica onde as instancias serao criadas"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Lista de Security Group IDs atribuidos ao frontend"
  type        = list(string)
}

variable "key_name" {
  description = "Nome da chave SSH registrada na AWS"
  type        = string
  default     = "lumina-deploy-key"
}

variable "lab_instance_profile_name" {
  description = "Nome do IAM Instance Profile pré-existente no Learner Lab"
  type        = string
  default     = "LabInstanceProfile"
}

variable "backend_endpoint" {
  description = "Endpoint DNS ou IP do Backend para proxy reverso no NGINX (ex: IP em dev ou ALB Interno em prod)"
  type        = string
}

variable "frontend_repo_url" {
  description = "URL do repositorio Git do Front-End"
  type        = string
  default     = "https://github.com/LuminaPI52CCOA/Front-End.git"
}

variable "frontend_repo_branch" {
  description = "Branch a ser clonada durante a subida"
  type        = string
  default     = "feat/lambda-alexa"
}

variable "target_group_arns" {
  description = "ARNs dos Target Groups para associacao automatica (ex: ALB Publico)"
  type        = list(string)
  default     = []
}

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
  description = "Quantidade de instancias de banco (1 em dev, 2 em prod)"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.small"
}

variable "subnet_ids" {
  description = "Lista de IDs de sub-rede onde as instancias serao criadas"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Lista de Security Group IDs atribuidos ao banco"
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

variable "db_name" {
  description = "Nome do schema do banco de dados (case-sensitive: Lumina)"
  type        = string
  default     = "Lumina"
}

variable "db_user" {
  description = "Usuario do banco de dados da aplicacao"
  type        = string
  default     = "lumina_user"
}

variable "db_password" {
  description = "Senha do usuario do banco"
  type        = string
  sensitive   = true
  default     = "LuminaSecurePass2026!"
}

variable "db_repo_url" {
  description = "URL do repositorio Git contendo o lumina.sql"
  type        = string
  default     = "https://github.com/LuminaPI52CCOA/Banco-de-dados.git"
}

variable "db_repo_branch" {
  description = "Branch contendo a versao atual do lumina.sql"
  type        = string
  default     = "feat/lambda-alexa"
}

variable "associate_public_ip_address" {
  description = "Atribuir IP publico (necessario em dev sem NAT Gateway para downloads/clones)"
  type        = bool
  default     = false
}

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

variable "is_dev" {
  description = "Flag indicando modo economico (aloca na sub-rede publica com IP publico para downloads diretos sem NAT)"
  type        = bool
  default     = true
}

variable "instance_count" {
  description = "Quantidade de instancias backend (1 em dev, 2 em prod)"
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
  description = "Lista de Security Group IDs atribuidos ao backend"
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

variable "db_private_ip" {
  description = "IP privado da instancia de banco de dados MySQL"
  type        = string
}

variable "db_name" {
  description = "Nome do schema do banco de dados (case-sensitive: Lumina)"
  type        = string
  default     = "Lumina"
}

variable "db_user" {
  description = "Usuario de acesso ao banco"
  type        = string
  default     = "lumina_user"
}

variable "db_password" {
  description = "Senha de acesso ao banco"
  type        = string
  sensitive   = true
  default     = "LuminaSecurePass2026!"
}

variable "jwt_secret" {
  description = "Chave secreta para assinatura dos tokens JWT"
  type        = string
  sensitive   = true
  default     = "minha-chave-secreta-super-segura-e-longa-para-o-jwt-token-lumina"
}

variable "jwt_validity" {
  description = "Tempo de validade do token JWT em milissegundos"
  type        = number
  default     = 86400000
}

variable "gemini_api_key" {
  description = "Chave de API do Google Gemini AI"
  type        = string
  sensitive   = true
  default     = "CHANGE_ME_GEMINI_KEY"
}

variable "backend_repo_url" {
  description = "URL do repositorio Git do Back-end"
  type        = string
  default     = "https://github.com/LuminaPI52CCOA/Back-end.git"
}

variable "backend_repo_branch" {
  description = "Branch a ser clonada durante a subida"
  type        = string
  default     = "feat/lambda-alexa"
}

variable "target_group_arns" {
  description = "ARNs dos Target Groups para associacao automatica (ex: ALB Interno em prod)"
  type        = list(string)
  default     = []
}

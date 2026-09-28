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

variable "instance_type_frontend" {
  description = "Tipo de instancia EC2 para o Frontend"
  type        = string
  default     = "t3.micro"
}

variable "instance_type_backend" {
  description = "Tipo de instancia EC2 para o Backend"
  type        = string
  default     = "t3.small"
}

variable "instance_type_database" {
  description = "Tipo de instancia EC2 para o Banco de Dados"
  type        = string
  default     = "t3.small"
}

variable "instance_type_bastion" {
  description = "Tipo de instancia EC2 para o Bastion Host"
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "Nome da chave SSH registrada na AWS"
  type        = string
  default     = "lumina-deploy-key"
}

variable "ssh_public_key" {
  description = "Chave publica SSH customizada (opcional)"
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Nome do schema do banco (case-sensitive: Lumina)"
  type        = string
  default     = "Lumina"
}

variable "db_user" {
  description = "Usuario do banco de dados da aplicacao"
  type        = string
  default     = "lumina_user"
}

variable "db_password" {
  description = "Senha do banco de dados da aplicacao"
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
  description = "Validade do token JWT em ms"
  type        = number
  default     = 86400000
}

variable "gemini_api_key" {
  description = "Chave da API do Google Gemini"
  type        = string
  sensitive   = true
  default     = "CHANGE_ME_GEMINI_KEY"
}

variable "backend_repo_url" {
  description = "URL do repositorio Git do Backend"
  type        = string
  default     = "https://github.com/LuminaPI52CCOA/Back-end.git"
}

variable "backend_repo_branch" {
  description = "Branch do repositorio Backend"
  type        = string
  default     = "feat/lambda-alexa"
}

variable "frontend_repo_url" {
  description = "URL do repositorio Git do Frontend"
  type        = string
  default     = "https://github.com/LuminaPI52CCOA/Front-End.git"
}

variable "frontend_repo_branch" {
  description = "Branch do repositorio Frontend"
  type        = string
  default     = "feat/lambda-alexa"
}

variable "db_repo_url" {
  description = "URL do repositorio Git do Banco de Dados"
  type        = string
  default     = "https://github.com/LuminaPI52CCOA/Banco-de-dados.git"
}

variable "db_repo_branch" {
  description = "Branch do repositorio Banco de Dados"
  type        = string
  default     = "feat/lambda-alexa"
}

variable "alexa_function_name" {
  description = "Nome da funcao Lambda da Skill Alexa em prod"
  type        = string
  default     = "lumina-alexa-skill-prod"
}

variable "alexa_service_email" {
  description = "Email do usuario tecnico para login da Lambda no backend"
  type        = string
  default     = "john@doe.com"
}

variable "alexa_service_password" {
  description = "Senha do usuario tecnico para login da Lambda no backend"
  type        = string
  sensitive   = true
  default     = "123456"
}

variable "alexa_skill_id" {
  description = "Skill ID no Alexa Developer Console (opcional)"
  type        = string
  default     = ""
}

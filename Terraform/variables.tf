variable "aws_region" {
  description = "Região da AWS onde a infraestrutura será provisionada"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto para identificação e prefixo dos recursos"
  type        = string
  default     = "devops-projeto"
}

variable "environment" {
  description = "Ambiente da infraestrutura (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC (indicado como 10.0.0.0/16 na arquitetura)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Lista de Zonas de Disponibilidade (A e B)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_1_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  type    = string
  default = "10.0.11.0/24"
}

variable "private_subnet_2_cidr" {
  type    = string
  default = "10.0.12.0/24"
}

variable "private_subnet_3_cidr" {
  type    = string
  default = "10.0.21.0/24"
}

variable "private_subnet_4_cidr" {
  type    = string
  default = "10.0.22.0/24"
}

variable "instance_type_frontend" {
  description = "Tipo da instância EC2 para o Frontend (React)"
  type        = string
  default     = "t3.micro"
}

variable "instance_type_backend" {
  description = "Tipo da instância EC2 para o Backend (Spring Boot)"
  type        = string
  default     = "t3.small"
}

variable "instance_type_database" {
  description = "Tipo da instância EC2 para o Banco de Dados (MySQL)"
  type        = string
  default     = "t3.small"
}

variable "instance_type_bastion" {
  description = "Tipo da instância EC2 para o Bastion Host / Jump Host"
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "Nome do par de chaves SSH registrado na AWS (ex: 'vockey' no AWS Academy)"
  type        = string
  default     = "vockey"
}

variable "ssh_private_key_path" {
  description = "Caminho do arquivo .pem da chave privada SSH"
  type        = string
  default     = "labsuser.pem"
}


variable "backend_repo_url" {
  description = "URL do repositório Git do Back-end Lumina"
  type        = string
  default     = "https://github.com/LuminaPI52CCOA/Back-end.git"
}

variable "backend_repo_branch" {
  type    = string
  default = "main"
}

variable "frontend_repo_url" {
  description = "URL do repositório Git do Front-end Lumina"
  type        = string
  default     = "https://github.com/LuminaPI52CCOA/Front-End.git"
}

variable "frontend_repo_branch" {
  type    = string
  default = "main"
}

variable "db_name" {
  type    = string
  default = "lumina_db"
}

variable "db_user" {
  type    = string
  default = "lumina_user"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "LuminaSecurePass2026!"
}

variable "jwt_secret" {
  type      = string
  sensitive = true
  default   = "minha-chave-secreta-super-segura-e-longa-para-o-jwt-token-lumina"
}

variable "jwt_validity" {
  type    = number
  default = 86400000
}

variable "gemini_api_key" {
  type      = string
  sensitive = true
  default   = "CHANGE_ME_GEMINI_KEY"
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "admin_ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "lab_role_name" {
  type    = string
  default = "LabRole"
}

variable "lab_instance_profile_name" {
  description = "Nome do IAM Instance Profile pré-existente no AWS Academy Learner Lab"
  type        = string
  default     = "LabInstanceProfile"
}


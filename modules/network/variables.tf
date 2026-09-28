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
  description = "Flag indicando modo dev economico"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Lista de Zonas de Disponibilidade"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Blocos CIDR das sub-redes publicas (minimo 2 para ALB)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "Blocos CIDR das sub-redes privadas de aplicacao (backend)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "Blocos CIDR das sub-redes privadas de banco de dados"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "enable_nat_gateway" {
  description = "Habilitar NAT Gateway e Elastic IP (desativado em dev, ativo em prod)"
  type        = bool
  default     = false
}

variable "enable_internal_alb" {
  description = "Habilitar Application Load Balancer Interno (desativado em dev, ativo em prod)"
  type        = bool
  default     = false
}

variable "admin_ssh_cidr" {
  description = "CIDR liberado para acesso administrativo via SSH"
  type        = string
  default     = "0.0.0.0/0"
}

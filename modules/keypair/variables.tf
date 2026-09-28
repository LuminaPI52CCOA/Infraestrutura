variable "key_name" {
  description = "Nome do par de chaves SSH registrado na AWS"
  type        = string
  default     = "lumina-deploy-key"
}

variable "public_key" {
  description = "Chave publica SSH (OpenSSH format). Se vazia, utiliza lumina-deploy-key.pub padrao."
  type        = string
  default     = ""
}

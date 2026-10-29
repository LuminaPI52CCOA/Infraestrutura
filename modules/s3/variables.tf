variable "bucket_name" {
  type        = string
  description = "Nome base do bucket"
}

variable "append_account_id" {
  type        = bool
  default     = true
  description = "Anexa automaticamente o ID da conta AWS ao final do nome do bucket para garantir unicidade global"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_event_notification" {
  type        = bool
  default     = false
  description = "Habilita a notificacao de eventos para o EventBridge"
}

variable "enable_cors" {
  type        = bool
  default     = false
  description = "Habilita regras de CORS para upload direto via browser"
}


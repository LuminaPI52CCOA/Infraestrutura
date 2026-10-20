variable "bucket_name" {
  type        = string
  description = "Nome base do bucket"
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


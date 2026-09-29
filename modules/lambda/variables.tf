variable "function_name" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "source_dir" {
  type = string
}

variable "handler" {
  type    = string
  default = "index.handler"
}

variable "runtime" {
  type    = string
  default = "python3.11"
}

variable "timeout" {
  type    = number
  default = 30
}

variable "memory_size" {
  type    = number
  default = 128
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "schedule_expression" {
  type        = string
  default     = ""
  description = "Expressao cron do EventBridge para agendamento (ex: 'cron(0 12 * * ? *)'). Vazio para nao criar trigger."
}

variable "tags" {
  type    = map(string)
  default = {}
}

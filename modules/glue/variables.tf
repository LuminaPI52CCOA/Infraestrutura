variable "job_name" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "script_bucket_id" {
  type        = string
  description = "Bucket S3 onde o script do Glue sera salvo"
}

variable "script_source_path" {
  type        = string
  description = "Caminho local para o arquivo Python do script Glue"
}

variable "trigger_bucket_name" {
  type        = string
  default     = ""
  description = "Nome do bucket S3 (ex: Bronze) que ira disparar o Job no evento ObjectCreated"
}

variable "default_arguments" {
  type    = map(string)
  default = {}
}

variable "glue_version" {
  type    = string
  default = "4.0"
}

variable "worker_type" {
  type    = string
  default = "G.1X"
}

variable "number_of_workers" {
  type    = number
  default = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "key_name" {
  description = "Nome do par de chaves criado"
  value       = aws_key_pair.this.key_name
}

output "key_pair_id" {
  description = "ID do recurso aws_key_pair"
  value       = aws_key_pair.this.id
}

output "key_pair_arn" {
  description = "ARN do recurso aws_key_pair"
  value       = aws_key_pair.this.arn
}

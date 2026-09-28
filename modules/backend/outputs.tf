output "instance_ids" {
  description = "IDs das instancias backend provisionadas"
  value       = aws_instance.backend[*].id
}

output "private_ips" {
  description = "IPs privados das instancias backend"
  value       = aws_instance.backend[*].private_ip
}

output "public_ips" {
  description = "IPs publicos das instancias backend (presentes em dev)"
  value       = aws_instance.backend[*].public_ip
}

output "primary_private_ip" {
  description = "IP privado da instancia principal de backend"
  value       = aws_instance.backend[0].private_ip
}

output "primary_public_ip" {
  description = "IP publico da instancia principal de backend (em dev)"
  value       = var.is_dev ? aws_instance.backend[0].public_ip : ""
}

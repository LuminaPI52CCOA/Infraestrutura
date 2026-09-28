output "instance_ids" {
  description = "IDs das instancias frontend provisionadas"
  value       = aws_instance.frontend[*].id
}

output "public_ips" {
  description = "IPs publicos das instancias frontend"
  value       = aws_instance.frontend[*].public_ip
}

output "private_ips" {
  description = "IPs privados das instancias frontend"
  value       = aws_instance.frontend[*].private_ip
}

output "primary_public_ip" {
  description = "IP publico da instancia principal de frontend"
  value       = aws_instance.frontend[0].public_ip
}

output "instance_ids" {
  description = "IDs das instancias de banco provisionadas"
  value       = aws_instance.database[*].id
}

output "private_ips" {
  description = "IPs privados das instancias de banco"
  value       = aws_instance.database[*].private_ip
}

output "primary_private_ip" {
  description = "IP privado da instancia principal de banco"
  value       = aws_instance.database[0].private_ip
}

output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "IDs das Sub-redes Públicas (AZ A e B)"
  value = {
    public_1 = aws_subnet.public_1.id
    public_2 = aws_subnet.public_2.id
  }
}

output "private_subnets_app" {
  description = "IDs das Sub-redes Privadas da Aplicação / Backend (AZ A e B)"
  value = {
    private_1 = aws_subnet.private_1.id
    private_2 = aws_subnet.private_2.id
  }
}

output "private_subnets_database" {
  description = "IDs das Sub-redes Privadas do Banco de Dados / Storage (AZ A e B)"
  value = {
    private_3 = aws_subnet.private_3.id
    private_4 = aws_subnet.private_4.id
  }
}

output "alb_public_dns_name" {
  description = "DNS público do Application Load Balancer"
  value       = aws_lb.public.dns_name
}

output "alb_internal_dns_name" {
  description = "DNS interno do Application Load Balancer Privado"
  value       = aws_lb.internal.dns_name
}

output "bastion_public_ip" {
  description = "IP público do Bastion Host"
  value       = aws_instance.bastion.public_ip
}

output "frontend_private_ips" {
  description = "IPs privados das instâncias Frontend"
  value = {
    frontend_az_a = aws_instance.frontend_a.private_ip
    frontend_az_b = aws_instance.frontend_b.private_ip
  }
}

output "backend_private_ips" {
  description = "IPs privados das instâncias Backend"
  value = {
    backend_az_a = aws_instance.backend_a.private_ip
    backend_az_b = aws_instance.backend_b.private_ip
  }
}

output "database_private_ips" {
  description = "IPs privados das instâncias do banco"
  value = {
    database_az_a = aws_instance.database_a.private_ip
    database_az_b = aws_instance.database_b.private_ip
  }
}

output "s3_bucket_name" {
  description = "Nome do Bucket S3"
  value       = local.s3_bucket_name
}

output "efs_dns_name" {
  description = "DNS do EFS"
  value       = aws_efs_file_system.shared_fs.dns_name
}

output "lambda_functions" {
  description = "ARNs das Funções Lambda"
  value = {
    top_trigger          = aws_lambda_function.lambda_top.arn
    formatar_json        = aws_lambda_function.formatar_json.arn
    corrigir_transcricao = aws_lambda_function.corrigir_transcricao.arn
  }
}

output "ssh_commands" {
  description = "Comandos para conectar via SSH com a chave labsuser.pem"
  value = {
    bastion       = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_instance.bastion.public_ip}"
    frontend_az_a = "ssh -i ${var.ssh_private_key_path} -J ubuntu@${aws_instance.bastion.public_ip} ubuntu@${aws_instance.frontend_a.private_ip}"
    backend_az_a  = "ssh -i ${var.ssh_private_key_path} -J ubuntu@${aws_instance.bastion.public_ip} ubuntu@${aws_instance.backend_a.private_ip}"
    database_az_a = "ssh -i ${var.ssh_private_key_path} -J ubuntu@${aws_instance.bastion.public_ip} ubuntu@${aws_instance.database_a.private_ip}"
  }
}



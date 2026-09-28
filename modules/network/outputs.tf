output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs das sub-redes publicas"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs das sub-redes privadas de aplicacao (backend)"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "IDs das sub-redes privadas de banco de dados"
  value       = aws_subnet.private_db[*].id
}

output "alb_public_dns" {
  description = "DNS publico do ALB da camada de entrada"
  value       = aws_lb.public.dns_name
}

output "alb_public_arn" {
  description = "ARN do ALB publico"
  value       = aws_lb.public.arn
}

output "alb_public_tg_frontend_arn" {
  description = "ARN do Target Group do Frontend no ALB Publico"
  value       = aws_lb_target_group.frontend.arn
}

output "alb_internal_dns" {
  description = "DNS interno do ALB da camada de aplicacao (prod)"
  value       = length(aws_lb.internal) > 0 ? aws_lb.internal[0].dns_name : ""
}

output "alb_internal_arn" {
  description = "ARN do ALB interno (prod)"
  value       = length(aws_lb.internal) > 0 ? aws_lb.internal[0].arn : ""
}

output "alb_internal_tg_backend_arn" {
  description = "ARN do Target Group do Backend no ALB Interno (prod)"
  value       = length(aws_lb_target_group.backend) > 0 ? aws_lb_target_group.backend[0].arn : ""
}

output "sg_alb_public_id" {
  description = "ID do Security Group do ALB Publico"
  value       = aws_security_group.alb_public.id
}

output "sg_bastion_id" {
  description = "ID do Security Group do Bastion Host"
  value       = aws_security_group.bastion.id
}

output "sg_frontend_id" {
  description = "ID do Security Group do Frontend"
  value       = aws_security_group.frontend.id
}

output "sg_alb_internal_id" {
  description = "ID do Security Group do ALB Interno"
  value       = length(aws_security_group.alb_internal) > 0 ? aws_security_group.alb_internal[0].id : ""
}

output "sg_backend_id" {
  description = "ID do Security Group do Backend"
  value       = aws_security_group.backend.id
}

output "sg_database_id" {
  description = "ID do Security Group do Database"
  value       = aws_security_group.database.id
}

output "sg_efs_id" {
  description = "ID do Security Group do EFS"
  value       = aws_security_group.efs.id
}

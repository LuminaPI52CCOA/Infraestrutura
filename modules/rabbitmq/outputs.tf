output "endpoint" {
  description = "DNS do Network Load Balancer (NLB) interno do RabbitMQ acessivel internamente pelas instancias EC2 na VPC"
  value       = aws_lb.rabbitmq.dns_name
}

output "port" {
  description = "Porta padrao AMQP do RabbitMQ"
  value       = 5672
}

output "management_port" {
  description = "Porta da interface de administracao do RabbitMQ"
  value       = 15672
}

output "security_group_id" {
  description = "ID do Security Group do RabbitMQ"
  value       = aws_security_group.rabbitmq.id
}

output "cluster_name" {
  description = "Nome do ECS Cluster do RabbitMQ"
  value       = aws_ecs_cluster.rabbitmq.name
}

output "service_name" {
  description = "Nome do ECS Service do RabbitMQ"
  value       = aws_ecs_service.rabbitmq.name
}

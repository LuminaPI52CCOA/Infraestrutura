output "endpoint" {
  description = "DNS privado de Service Discovery do RabbitMQ acessivel internamente na VPC"
  value       = "${aws_service_discovery_service.rabbitmq.name}.${aws_service_discovery_private_dns_namespace.lumina.name}"
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

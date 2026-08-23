output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = module.ecs.alb_dns_name
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "service_name" {
  description = "Name of the ECS Fargate service"
  value       = module.ecs.service_name
}

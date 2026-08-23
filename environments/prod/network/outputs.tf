output "vpc_id" {
  description = "ID of the environment VPC"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets in the VPC"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets in the VPC"
  value       = module.network.private_subnet_ids
}

output "alb_sg_id" {
  description = "ID of the ALB security group"
  value       = module.network.alb_sg_id
}

output "ecs_sg_id" {
  description = "ID of the ECS security group"
  value       = module.network.ecs_sg_id
}

output "db_sg_id" {
  description = "ID of the database security group"
  value       = module.network.db_sg_id
}

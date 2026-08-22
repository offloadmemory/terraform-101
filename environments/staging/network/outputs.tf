output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "alb_sg_id" {
  value = module.network.alb_sg_id
}

output "ecs_sg_id" {
  value = module.network.ecs_sg_id
}

output "db_sg_id" {
  value = module.network.db_sg_id
}

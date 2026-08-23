# Minimal composition that showcases modules/ecs.
#
#   terraform init && terraform apply
#
# Requires a VPC, public/private subnets, and ALB/ECS security groups
# (normally provided by the `network` workspace via terraform_remote_state).
terraform {
  required_version = "~> 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "ecs" {
  source = "../../"

  env                = var.env
  region             = var.region
  image              = var.image
  cpu                = var.cpu
  memory             = var.memory
  desired_count      = var.desired_count
  vpc_id             = var.vpc_id
  public_subnet_ids  = var.public_subnet_ids
  private_subnet_ids = var.private_subnet_ids
  alb_sg_id          = var.alb_sg_id
  ecs_sg_id          = var.ecs_sg_id
  tags               = var.tags
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = module.ecs.alb_dns_name
}

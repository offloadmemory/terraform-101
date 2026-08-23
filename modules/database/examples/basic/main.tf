# Minimal composition that showcases modules/database.
#
#   terraform init && terraform apply
#
# Requires an existing VPC + private subnets + a DB security group. In the
# real repo these come from the `network` workspace via terraform_remote_state;
# here they are provided as plain variables for a self-contained example.
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

module "database" {
  source = "../../"

  env                     = var.env
  db_name                 = var.db_name
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  backup_retention_period = var.backup_retention_period
  multi_az                = var.multi_az
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot
  subnet_ids              = var.subnet_ids
  db_sg_id                = var.db_sg_id
  tags                    = var.tags
}

output "db_endpoint" {
  description = "Hostname endpoint of the RDS database"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "db_port" {
  description = "Port on which the database accepts connections"
  value       = module.database.db_port
  sensitive   = true
}

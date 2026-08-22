provider "aws" {
  region  = var.region
  profile = var.profile
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket         = "tfstate-${var.env_name}"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    profile        = var.profile
    dynamodb_table = "tfstate-${var.env_name}-lock"
  }
}

module "database" {
  source = "../../../modules/database"

  env                     = var.env_name
  db_name                 = var.db_name
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  backup_retention_period = var.backup_retention_period
  multi_az                = var.multi_az
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot
  subnet_ids              = data.terraform_remote_state.network.outputs.private_subnet_ids
  db_sg_id                = data.terraform_remote_state.network.outputs.db_sg_id
  tags                    = var.tags
}

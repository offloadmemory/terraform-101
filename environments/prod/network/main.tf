provider "aws" {
  region  = var.region
  profile = var.profile
}

module "network" {
  source = "../../../modules/network"

  env_name             = var.env_name
  region               = var.region
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  nat_gateway_count    = var.nat_gateway_count
  tags                 = var.tags
}

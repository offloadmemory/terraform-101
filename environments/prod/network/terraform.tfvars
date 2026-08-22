region               = "us-east-1"
profile              = "prod"
env_name             = "prod"
vpc_cidr             = "10.2.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.2.0.0/24", "10.2.1.0/24", "10.2.2.0/24"]
private_subnet_cidrs = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]
nat_gateway_count    = 1
tags = {
  env        = "prod"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}

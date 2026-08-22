region               = "us-east-1"
profile              = "dev"
env_name             = "dev"
vpc_cidr             = "10.0.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
nat_gateway_count    = 1
tags = {
  env        = "dev"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}

region               = "us-east-1"
profile              = "staging"
env_name             = "staging"
vpc_cidr             = "10.1.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]
nat_gateway_count    = 1
tags = {
  env        = "staging"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}

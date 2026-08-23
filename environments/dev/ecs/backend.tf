terraform {
  backend "s3" {
    bucket       = "tfstate-dev"
    key          = "ecs/terraform.tfstate"
    region       = "us-east-1"
    profile      = "dev"
    use_lockfile = true
    encrypt      = true
  }
}

terraform {
  backend "s3" {
    bucket       = "tfstate-dev-kartik-2026"
    key          = "ecs/terraform.tfstate"
    region       = "ap-south-1"
    profile      = "dev"
    use_lockfile = true
    encrypt      = true
  }
}

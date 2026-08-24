terraform {
  backend "s3" {
    bucket       = "tfstate-prod-kartik-2026"
    key          = "database/terraform.tfstate"
    region       = "ap-south-1"
    profile      = "prod"
    use_lockfile = true
    encrypt      = true
  }
}

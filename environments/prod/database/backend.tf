terraform {
  backend "s3" {
    bucket       = "tfstate-prod"
    key          = "database/terraform.tfstate"
    region       = "us-east-1"
    profile      = "prod"
    use_lockfile = true
    encrypt      = true
  }
}

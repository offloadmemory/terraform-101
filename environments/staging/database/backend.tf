terraform {
  backend "s3" {
    bucket       = "tfstate-staging-kartik-2026"
    key          = "database/terraform.tfstate"
    region       = "ap-south-1"
    profile      = "staging"
    use_lockfile = true
    encrypt      = true
  }
}

terraform {
  backend "s3" {
    bucket       = "tfstate-staging"
    key          = "network/terraform.tfstate"
    region       = "us-east-1"
    profile      = "staging"
    use_lockfile = true
    encrypt      = true
  }
}

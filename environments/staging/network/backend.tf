terraform {
  backend "s3" {
    bucket         = "tfstate-staging"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-staging-lock"
    encrypt        = true
  }
}

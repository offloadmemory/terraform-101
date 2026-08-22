terraform {
  backend "s3" {
    bucket         = "tfstate-prod"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    profile        = "prod"
    dynamodb_table = "tfstate-prod-lock"
    encrypt        = true
  }
}

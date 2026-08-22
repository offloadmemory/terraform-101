terraform {
  backend "s3" {
    bucket         = "tfstate-dev"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    profile        = "dev"
    dynamodb_table = "tfstate-dev-lock"
    encrypt        = true
  }
}

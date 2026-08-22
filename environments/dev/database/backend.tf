terraform {
  backend "s3" {
    bucket         = "tfstate-dev"
    key            = "database/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-dev-lock"
    encrypt        = true
  }
}

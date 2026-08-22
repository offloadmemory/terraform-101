terraform {
  backend "s3" {
    bucket         = "tfstate-prod"
    key            = "ecs/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-prod-lock"
    encrypt        = true
  }
}

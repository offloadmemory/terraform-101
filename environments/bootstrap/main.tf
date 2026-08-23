module "state_dev" {
  source = "../../modules/state"

  providers = {
    aws = aws.dev
  }

  bucket_name = "tfstate-dev"
  tags = {
    Name    = "tfstate-dev"
    env     = "dev"
    project = "terraform-101-demo"
  }
}

module "state_staging" {
  source = "../../modules/state"

  providers = {
    aws = aws.staging
  }

  bucket_name = "tfstate-staging"
  tags = {
    Name    = "tfstate-staging"
    env     = "staging"
    project = "terraform-101-demo"
  }
}

module "state_prod" {
  source = "../../modules/state"

  providers = {
    aws = aws.prod
  }

  bucket_name = "tfstate-prod"
  tags = {
    Name    = "tfstate-prod"
    env     = "prod"
    project = "terraform-101-demo"
  }
}

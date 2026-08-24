module "state_dev" {
  source = "../../modules/state"

  providers = {
    aws = aws.dev
  }

  bucket_name = "tfstate-dev-kartik-2026"
  tags = {
    Name    = "tfstate-dev-kartik-2026"
    env     = "dev"
    project = "terraform-101-demo"
  }
}

module "state_staging" {
  source = "../../modules/state"

  providers = {
    aws = aws.staging
  }

  bucket_name = "tfstate-staging-kartik-2026"
  tags = {
    Name    = "tfstate-staging-kartik-2026"
    env     = "staging"
    project = "terraform-101-demo"
  }
}

module "state_prod" {
  source = "../../modules/state"

  providers = {
    aws = aws.prod
  }

  bucket_name = "tfstate-prod-kartik-2026"
  tags = {
    Name    = "tfstate-prod-kartik-2026"
    env     = "prod"
    project = "terraform-101-demo"
  }
}

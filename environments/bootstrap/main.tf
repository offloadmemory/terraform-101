provider "aws" {
  alias   = "dev"
  region  = "us-east-1"
  profile = "dev"
}

provider "aws" {
  alias   = "staging"
  region  = "us-east-1"
  profile = "staging"
}

provider "aws" {
  alias   = "prod"
  region  = "us-east-1"
  profile = "prod"
}

module "state_dev" {
  source = "../../modules/state"

  providers = {
    aws = aws.dev
  }

  bucket_name = "tfstate-dev"
  region      = "us-east-1"
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
  region      = "us-east-1"
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
  region      = "us-east-1"
  tags = {
    Name    = "tfstate-prod"
    env     = "prod"
    project = "terraform-101-demo"
  }
}

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

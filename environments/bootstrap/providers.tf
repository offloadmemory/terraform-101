provider "aws" {
  alias   = "dev"
  region  = "ap-south-1"
  profile = "dev"
}

provider "aws" {
  alias   = "staging"
  region  = "ap-south-1"
  profile = "staging"
}

provider "aws" {
  alias   = "prod"
  region  = "ap-south-1"
  profile = "prod"
}

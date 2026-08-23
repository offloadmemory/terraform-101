# Minimal composition that calls modules/state.
#
#   terraform init && terraform apply
#
# Creates one state bucket. Set `bucket_name` to something globally unique.
terraform {
  required_version = "~> 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "state" {
  source = "../../"

  bucket_name = var.bucket_name
  tags        = var.tags
}

output "bucket_name" {
  description = "Name of the created state bucket"
  value       = module.state.bucket_name
}

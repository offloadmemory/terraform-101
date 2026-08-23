# Default TFLint configuration for the repository.
#
# tflint is a static-analysis tool that catches provider-API-level mistakes
# that `terraform validate` cannot (invalid instance classes, hardcoded
# region references, missing tags, etc.). Run locally with:
#   tflint --init && tflint
plugin "aws" {
  enabled = true
  version = "0.35.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

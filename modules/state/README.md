# module `state`

Per-account S3 state bucket with the enterprise hygiene an S3 backend needs:
versioning, SSE-AES256 encryption, a public-access block, and a
deny-insecure-transport bucket policy. S3-native lockfiles (`use_lockfile`)
live inside the same bucket, so no DynamoDB is required.

> **Scope:** bootstrap-only. This module is called from
> `environments/bootstrap/` once per account, never from an environment
> component.

## Usage

```hcl
module "state" {
  source = "../../modules/state"

  bucket_name = "tfstate-dev-kartik-2026"
  tags = {
    env        = "dev"
    project    = "terraform-101-demo"
    managed_by = "terraform"
  }
}
```

## Example

See [examples/basic](examples/basic) for a complete root module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_s3_bucket.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Globally unique S3 bucket name for remote state | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags applied to state resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | n/a |
<!-- END_TF_DOCS -->

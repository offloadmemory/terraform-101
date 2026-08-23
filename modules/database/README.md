# module `database`

RDS PostgreSQL instance + subnet group with AWS-managed master password
(`manage_master_user_password`) — no password ever appears in code or state
plaintext.

## Usage

```hcl
module "database" {
  source = "../../modules/database"

  env                     = "dev"
  db_name                 = "appdb"
  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  backup_retention_period = 7
  multi_az                = false
  deletion_protection     = false
  skip_final_snapshot     = true
  subnet_ids              = data.terraform_remote_state.network.outputs.private_subnet_ids
  db_sg_id                = data.terraform_remote_state.network.outputs.db_sg_id
  tags                    = { env = "dev", managed_by = "terraform" }
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
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | Name of the initial database | `string` | n/a | yes |
| <a name="input_db_sg_id"></a> [db\_sg\_id](#input\_db\_sg\_id) | Security group id that allows 5432 ingress from ECS | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | Environment name (dev/staging/prod) | `string` | n/a | yes |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | RDS instance class | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Private subnet IDs for the DB subnet group | `list(string)` | n/a | yes |
| <a name="input_allocated_storage"></a> [allocated\_storage](#input\_allocated\_storage) | Allocated storage in GiB | `number` | `20` | no |
| <a name="input_backup_retention_period"></a> [backup\_retention\_period](#input\_backup\_retention\_period) | Backup retention in days | `number` | `1` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Prevent accidental deletion | `bool` | `false` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Deploy across multiple AZs | `bool` | `false` | no |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Skip final snapshot on destroy (dev convenience) | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_db_endpoint"></a> [db\_endpoint](#output\_db\_endpoint) | Hostname endpoint of the RDS database |
| <a name="output_db_name"></a> [db\_name](#output\_db\_name) | Name of the database |
| <a name="output_db_port"></a> [db\_port](#output\_db\_port) | Port on which the database accepts connections |
| <a name="output_db_sg_id"></a> [db\_sg\_id](#output\_db\_sg\_id) | ID of the security group attached to the database |
<!-- END_TF_DOCS -->

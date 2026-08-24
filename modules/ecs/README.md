# module `ecs`

ECS cluster + Fargate service + task definition + ALB with listener + the
IAM roles the platform needs (execution and task roles).

## Usage

```hcl
module "ecs" {
  source = "../../modules/ecs"

  env                = "dev"
  region             = "ap-south-1"
  image              = "nginx:alpine"
  cpu                = "256"
  memory             = "512"
  desired_count      = 1
  vpc_id             = var.vpc_id
  public_subnet_ids  = var.public_subnet_ids
  private_subnet_ids = var.private_subnet_ids
  alb_sg_id          = var.alb_sg_id
  ecs_sg_id          = var.ecs_sg_id
  tags               = { env = "dev", managed_by = "terraform" }
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
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.ecs_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ecs_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alb_sg_id"></a> [alb\_sg\_id](#input\_alb\_sg\_id) | ALB security group ID | `string` | n/a | yes |
| <a name="input_ecs_sg_id"></a> [ecs\_sg\_id](#input\_ecs\_sg\_id) | ECS task security group ID | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | Environment name (dev/staging/prod) | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs for the Fargate tasks | `list(string)` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | Public subnet IDs for the ALB | `list(string)` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID for the target group | `string` | n/a | yes |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | Task CPU units | `string` | `"256"` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Number of running tasks | `number` | `1` | no |
| <a name="input_image"></a> [image](#input\_image) | Container image for the app task | `string` | `"nginx:alpine"` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Task memory MiB | `string` | `"512"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the application load balancer |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the ECS cluster |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Name of the ECS Fargate service |
<!-- END_TF_DOCS -->

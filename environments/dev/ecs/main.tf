data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket  = "tfstate-${var.env_name}"
    key     = "network/terraform.tfstate"
    region  = "us-east-1"
    profile = var.profile
  }
}

module "ecs" {
  source = "../../../modules/ecs"

  env                = var.env_name
  region             = var.region
  image              = var.image
  cpu                = var.cpu
  memory             = var.memory
  desired_count      = var.desired_count
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.network.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  alb_sg_id          = data.terraform_remote_state.network.outputs.alb_sg_id
  ecs_sg_id          = data.terraform_remote_state.network.outputs.ecs_sg_id
  tags               = var.tags
}

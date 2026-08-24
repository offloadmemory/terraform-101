region        = "ap-south-1"
profile       = "prod"
env_name      = "prod"
image         = "nginx:alpine"
cpu           = "256"
memory        = "512"
desired_count = 1
tags = {
  env        = "prod"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}

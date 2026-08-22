region        = "us-east-1"
profile       = "dev"
env_name      = "dev"
image         = "nginx:alpine"
cpu           = "256"
memory        = "512"
desired_count = 1
tags = {
  env        = "dev"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}

region        = "us-east-1"
profile       = "staging"
env_name      = "staging"
image         = "nginx:alpine"
cpu           = "256"
memory        = "512"
desired_count = 1
tags = {
  env        = "staging"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}

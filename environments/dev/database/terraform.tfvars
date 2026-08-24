region                  = "ap-south-1"
profile                 = "dev"
env_name                = "dev"
db_name                 = "appdb"
instance_class          = "db.t4g.micro"
allocated_storage       = 20
backup_retention_period = 1
multi_az                = false
deletion_protection     = false
skip_final_snapshot     = true
tags = {
  env        = "dev"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}

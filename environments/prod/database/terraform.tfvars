region                  = "ap-south-1"
profile                 = "prod"
env_name                = "prod"
db_name                 = "appdb"
instance_class          = "db.t4g.small"
allocated_storage       = 50
backup_retention_period = 7
multi_az                = true
deletion_protection     = true
skip_final_snapshot     = false
tags = {
  env        = "prod"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}
